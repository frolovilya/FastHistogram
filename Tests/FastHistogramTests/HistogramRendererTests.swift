import XCTest
import simd
import Combine
@testable import FastHistogram

struct P: Hashable {
    let x, y: Int
    
    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}

final class HistogramRendererTests: XCTestCase {
        
    var gpuHandler: GPUHandler!
    var histogramGenerator: HistogramGenerator!
    var histogramRenderer: HistogramRenderer!
    var texturePool: SharedResourcePool<HistogramTexture>!
    var outputTexture: HistogramTexture!
    var outputTextureCancellables: [AnyCancellable] = []

    override func setUpWithError() throws {
        gpuHandler = try GPUHandler()

        texturePool = HistogramTexture.makePool(gpuHandler: gpuHandler,
                                                width: 2,
                                                height: 2,
                                                poolSize: 3)
    }
    
    func checkOutput(inputPixels: [UInt8],
                     outputPixels: [P: RGBAColor],
                     binsCount: Int,
                     width: Int,
                     height: Int,
                     layersOpacity: Double = 1) -> Void {
        histogramGenerator = try! HistogramGenerator(gpuHandler: gpuHandler,
                                                     binsCount: binsCount)
        
        outputTexture = HistogramTexture(gpuHandler: gpuHandler,
                                         width: width,
                                         height: height,
                                         isRenderTarget: true)
        
        histogramRenderer = try! HistogramRenderer(gpuHandler: gpuHandler,
                                                   renderTarget: outputTexture,
                                                   redLayerColor: RGBAColor.red.opacity(layersOpacity),
                                                   greenLayerColor: RGBAColor.green.opacity(layersOpacity),
                                                   blueLayerColor: RGBAColor.blue.opacity(layersOpacity),
                                                   luminanceLayerColor: RGBAColor.white.opacity(layersOpacity))

        let inputTexture = texturePool.nextResource
        inputTexture.fillTextureWithBGRAPixelData(pixelData: inputPixels)
        
        let histogramRenderedExpectation = expectation(description: "histogram rendered")
        histogramRenderedExpectation.expectedFulfillmentCount = 1
        
        outputTextureCancellables.append(outputTexture.didRenderPublisher
                                            .receive(on: DispatchQueue.main)
                                            .sink { _ in
            histogramRenderedExpectation.fulfill()
            self.outputTexture.dumpTextureContents()
            
            for w in 0..<self.outputTexture.size.width {
                for h in 0..<self.outputTexture.size.height {
                    let expectedColor: RGBAColor = outputPixels[P(w, h)] ?? RGBAColor.black
                    XCTAssertEqual(self.outputTexture.getPixelColor(x: w, y: h),
                                   expectedColor,
                                   "(\(w), \(h))")
                }
            }
        })
        
        histogramGenerator.process(texture: inputTexture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()
            self.histogramRenderer.draw(histogramBuffer: histogramBuffer,
                                        showRed: true,
                                        showGreen: true,
                                        showBlue: true,
                                        showLuminance: true)
        }
        
        wait(for: [histogramRenderedExpectation], timeout: 1)
    }
    
    func testWhite_10bins_10x4texture() {
        checkOutput(
            inputPixels: [
                255, 255, 255, 255,
                255, 255, 255, 255,
                255, 255, 255, 255,
                255, 255, 255, 255
            ],
            outputPixels: [
                P(9, 0): RGBAColor.white,
                P(9, 1): RGBAColor.white,
                P(9, 2): RGBAColor.white,
                P(9, 3): RGBAColor.white
            ],
            binsCount: 10,
            width: 10,
            height: 4
        )
    }
    
    func testBlack_10bins_10x4texture() {
        checkOutput(
            inputPixels: [
                0, 0, 0, 255,
                0, 0, 0, 255,
                0, 0, 0, 255,
                0, 0, 0, 255
            ],
            outputPixels: [
                P(0, 0): RGBAColor.white,
                P(0, 1): RGBAColor.white,
                P(0, 2): RGBAColor.white,
                P(0, 3): RGBAColor.white
            ],
            binsCount: 10,
            width: 10,
            height: 4
        )
    }
    
    func test18Gray_10bins_10x4texture() {
        let grayBin = TestUtils.binIndex(119 / 255, binsCount: 10)
        
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [
                P(grayBin, 0): RGBAColor.white,
                P(grayBin, 1): RGBAColor.white,
                P(grayBin, 2): RGBAColor.white,
                P(grayBin, 3): RGBAColor.white
            ],
            binsCount: 10,
            width: 10,
            height: 4
        )
    }
    
    func test18Gray_10bins_10x4texture_withBlending() {
        let grayBin = TestUtils.binIndex(119 / 255, binsCount: 10)
        
        // (183, 194, 232, 178)
        let blendedColor = RGBAColor.white.opacity(0.7)
            .add(RGBAColor.blue.opacity(0.7)
                    .add(RGBAColor.green.opacity(0.7)
                            .add(RGBAColor.red.opacity(0.7)
                                    .add(RGBAColor.black.opacity(0.7)))))
        
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [
                P(grayBin, 0): blendedColor,
                P(grayBin, 1): blendedColor,
                P(grayBin, 2): blendedColor,
                P(grayBin, 3): blendedColor
            ],
            binsCount: 10,
            width: 10,
            height: 4,
            layersOpacity: 0.7
        )
    }
    
    func test18Gray_10bins_20x4texture() {
        let grayBin = Int(Double(TestUtils.binIndex(119 / 255, binsCount: 10)) * (20 / 10.0))
        
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [
                P(grayBin, 0): RGBAColor.white,
                P(grayBin + 1, 0): RGBAColor.white,
                P(grayBin, 1): RGBAColor.white,
                P(grayBin + 1, 1): RGBAColor.white,
                P(grayBin, 2): RGBAColor.white,
                P(grayBin + 1, 2): RGBAColor.white,
                P(grayBin, 3): RGBAColor.white,
                P(grayBin + 1, 3): RGBAColor.white
            ],
            binsCount: 10,
            width: 20,
            height: 4
        )
    }
    
    func test18Gray_10bins_6x4texture() {
        let grayBin = Int(Double(TestUtils.binIndex(119 / 255, binsCount: 10)) * (6 / 10.0))
        
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [
                P(grayBin, 0): RGBAColor.white,
                P(grayBin, 1): RGBAColor.white,
                P(grayBin, 2): RGBAColor.white,
                P(grayBin, 3): RGBAColor.white,
            ],
            binsCount: 10,
            width: 6,
            height: 4
        )
    }
    
    func test18Gray_10bins_4x4texture() {
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [:],
            binsCount: 10,
            width: 4,
            height: 4
        )
    }
    
    func test18Gray_256bins_256x4texture() {
        checkOutput(
            inputPixels: [
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255,
                119, 119, 119, 255
            ],
            outputPixels: [
                P(119, 0): RGBAColor.white,
                P(119, 1): RGBAColor.white,
                P(119, 2): RGBAColor.white,
                P(119, 3): RGBAColor.white
            ],
            binsCount: 256,
            width: 256,
            height: 4
        )
    }
    
    /*
     4 pixels with pure RGB colors.
     
     Since these aren't gray colors, using the following perception coefficients to get luminance:
     (0.2126 * r + 0.7152 * g + 0.0722 * b)
     */
    func testPureRgb_256bins_256x3texture_noBlending() {
        let redBin = TestUtils.binIndex(TestUtils.redPerception, binsCount: 256)
        let greenBin = TestUtils.binIndex(TestUtils.greenPerception, binsCount: 256)
        let blueBin = TestUtils.binIndex(TestUtils.bluePerception, binsCount: 256)

        // maxBinValues = RGBLBin(3, 2, 3, 2)
        checkOutput(
            inputPixels: [ // BGRA
                0,   255, 0,   255, // green
                255, 0,   0,   255, // blue
                0,   0,   255, 255, // red
                0,   255, 0,   255  // green
            ],
            outputPixels: [
                // RGBLBin(3, 2, 3, 0)
                P(0, 0): RGBAColor.blue, // blue covers green and red
                P(0, 1): RGBAColor.blue,
                P(0, 2): RGBAColor.blue,
                
                // RGBLBin(0, 0, 0, 1)
                P(redBin, 1): RGBAColor.white,
                P(redBin, 2): RGBAColor.white,

                // RGBLBin(0, 0, 0, 2)
                P(greenBin, 0): RGBAColor.white,
                P(greenBin, 1): RGBAColor.white,
                P(greenBin, 2): RGBAColor.white,
                
                // RGBLBin(0, 0, 0, 1)
                P(blueBin, 1): RGBAColor.white,
                P(blueBin, 2): RGBAColor.white,

                // RGBLBin(1, 2, 1, 0)
                P(255, 0): RGBAColor.green, // green covers blue and red
                P(255, 1): RGBAColor.green,
                P(255, 2): RGBAColor.blue // bottom, blue covers green
            ],
            binsCount: 256,
            width: 256,
            height: 3
        )
    }
    
    func testPureRgb_256bins_256x3texture_withBlending() {
        let redBin = TestUtils.binIndex(TestUtils.redPerception, binsCount: 256)
        let greenBin = TestUtils.binIndex(TestUtils.greenPerception, binsCount: 256)
        let blueBin = TestUtils.binIndex(TestUtils.bluePerception, binsCount: 256)
        
        let whiteBlack = RGBAColor.white.opacity(0.7)
            .add(RGBAColor.black.opacity(0.7))
        
        let bgrBlack = RGBAColor.blue.opacity(0.7)
            .add(RGBAColor.green.opacity(0.7)
                    .add(RGBAColor.red.opacity(0.7)
                            .add(RGBAColor.black.opacity(0.7))))
        
        let greenBlack = RGBAColor.green.opacity(0.7)
            .add(RGBAColor.black.opacity(0.7))
        
        // maxBinValues = RGBLBin(3, 2, 3, 2)
        checkOutput(
            inputPixels: [ // BGRA
                0,   255, 0,   255, // green
                255, 0,   0,   255, // blue
                0,   0,   255, 255, // red
                0,   255, 0,   255  // green
            ],
            outputPixels: [
                // RGBLBin(3, 2, 3, 0)
                P(0, 0): bgrBlack,
                P(0, 1): bgrBlack,
                P(0, 2): bgrBlack,
                
                // RGBLBin(0, 0, 0, 1)
                P(redBin, 1): whiteBlack,
                P(redBin, 2): whiteBlack,

                // RGBLBin(0, 0, 0, 2)
                P(greenBin, 0): whiteBlack,
                P(greenBin, 1): whiteBlack,
                P(greenBin, 2): whiteBlack,
                
                // RGBLBin(0, 0, 0, 1)
                P(blueBin, 1): whiteBlack,
                P(blueBin, 2): whiteBlack,

                // RGBLBin(1, 2, 1, 0)
                P(255, 0): greenBlack,
                P(255, 1): greenBlack,
                P(255, 2): bgrBlack
            ],
            binsCount: 256,
            width: 256,
            height: 3,
            layersOpacity: 0.7
        )
    }

    static var allTests = [
        ("testWhite_10bins_10x4texture", testWhite_10bins_10x4texture),
        ("testBlack_10bins_10x4texture", testBlack_10bins_10x4texture),
        ("test18Gray_10bins_10x4texture", test18Gray_10bins_10x4texture),
        ("test18Gray_10bins_10x4texture_withBlending", test18Gray_10bins_10x4texture_withBlending),
        ("test18Gray_10bins_20x4texture", test18Gray_10bins_20x4texture),
        ("test18Gray_10bins_6x4texture", test18Gray_10bins_6x4texture),
        ("test18Gray_10bins_4x4texture", test18Gray_10bins_4x4texture),
        ("test18Gray_256bins_256x4texture", test18Gray_256bins_256x4texture),
        ("testPureRgb_256bins_256x3texture_noBlending", testPureRgb_256bins_256x3texture_noBlending),
        ("testPureRgb_256bins_256x3texture_withBlending", testPureRgb_256bins_256x3texture_withBlending)
    ]
}
