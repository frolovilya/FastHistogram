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
                     height: Int) -> Void {
        histogramGenerator = try! HistogramGenerator(gpuHandler: gpuHandler,
                                                     binsCount: binsCount)
        
        outputTexture = HistogramTexture(gpuHandler: gpuHandler,
                                         width: width,
                                         height: height,
                                         isRenderTarget: true)
        
        histogramRenderer = try! HistogramRenderer(gpuHandler: gpuHandler,
                                                   renderTarget: outputTexture)

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
                    XCTAssertEqual(self.outputTexture.getPixelColor(x: w, y: h), expectedColor)
                }
            }
        })
        
        histogramGenerator.process(texture: inputTexture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()
            self.histogramRenderer.draw(histogramBuffer: histogramBuffer)
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
    
    func test18Gray_10bins_20x4texture() {
        let grayBin = TestUtils.binIndex(119 / 255, binsCount: 10) * 2
        
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

    static var allTests = [
        ("testWhite_10bins_10x4texture", testWhite_10bins_10x4texture),
        ("testBlack_10bins_10x4texture", testBlack_10bins_10x4texture)
    ]
}
