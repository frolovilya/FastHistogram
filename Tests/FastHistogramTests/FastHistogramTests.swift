import XCTest
import simd
@testable import FastHistogram

final class FastHistogramTests: XCTestCase {
    
    private static let binsCount: Int = 256
    
    var gpuHandler: GPUHandler!
    var histogramGenerator: HistogramGenerator!
    var texturePool: SharedResourcePool<HistogramTexture>!
    
    override func setUpWithError() throws {
        gpuHandler = try GPUHandler()
        histogramGenerator = try HistogramGenerator(gpuHandler: gpuHandler,
                                                    binsCount: FastHistogramTests.binsCount)
        texturePool = HistogramTexture.makePool(device: gpuHandler.device,
                                                    textureSize: MTLSizeMake(2, 2, 1),
                                                    poolSize: 3)
    }

    private func linearize(_ value: Double) -> Double {
        pow((value + 0.055) / 1.055, 2.4)
    }
    
    private func binIndex(_ value: Double) -> Int {
        Int(round(value * Double(FastHistogramTests.binsCount - 1)))
    }
    
    private func checkHistogramBuffer(histogram: HistogramBuffer,
                                      expectedBins: [Int: RGBLBin]) -> Void {
        for i in 0..<histogram.binsCount {
            let expectedBin = expectedBins[i] != nil ? expectedBins[i]! : RGBLBin(0, 0, 0, 0)
            let actualBin = histogram.getBin(index: i)
            
            print(i, expectedBin, actualBin)
            XCTAssertEqual(actualBin, expectedBin)
        }
    }
    
    /*
     All 4 pixels of white RGB(255, 255, 255) color
     */
    func testWhite() {
        let pixelData: [UInt8] = [
            255, 255, 255, 255,
            255, 255, 255, 255,
            255, 255, 255, 255,
            255, 255, 255, 255
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)
        
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()
            
            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [FastHistogramTests.binsCount - 1: RGBLBin(4, 4, 4, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
    }
    
    /*
     All 4 pixels of black RGB(0, 0, 0) color
     */
    func testBlack() {
        let pixelData: [UInt8] = [
            0, 0, 0, 255,
            0, 0, 0, 255,
            0, 0, 0, 255,
            0, 0, 0, 255
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)
        
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()
            
            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [0: RGBLBin(4, 4, 4, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
    }
    
    /*
     All 4 pixels of gray RGB(119, 119, 119) color.
     
     Assuming 119 is gamma encoded (with gamma=2.4), it's gamma luminance is ~47%.
     Linearized luminance is:
     (119/255)^2.4 = ~16%
     */
    func test18Gray() {
        let pixelData: [UInt8] = [
            119, 119, 119, 255,
            119, 119, 119, 255,
            119, 119, 119, 255,
            119, 119, 119, 255
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)
        
        // calculate gamma encoded histogram
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()
            
            let gammaEncodedBinIndex = 119
            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [gammaEncodedBinIndex: RGBLBin(4, 4, 4, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
        
        // calculate linearized histogram
        histogramGenerator.process(texture: texture, isLinear: true) { histogramBuffer in
            histogramBuffer.dumpBufferContents()

            let linearizedBinIndex = self.binIndex(self.linearize(119.0/255))
            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [linearizedBinIndex: RGBLBin(4, 4, 4, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
    }
    
    /*
     4 pixels with pure RGB colors.
     
     Since these aren't gray colors, using the following perception coefficients to get luminance:
     (0.2126 * r + 0.7152 * g + 0.0722 * b)
     */
    func testPureRgb() {
        // BGRA
        let pixelData: [UInt8] = [
            0,   255, 0,   255, // green
            255, 0,   0,   255, // blue
            0,   0,   255, 255, // red
            0,   255, 0,   255  // green
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)
        
        let redBin = binIndex(0.2126)
        let greenBin = binIndex(0.7152)
        let blueBin = binIndex(0.0722)
        
        // calculate gamma encoded histogram
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()

            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [0: RGBLBin(3, 2, 3, 0),
                                                     255: RGBLBin(1, 2, 1, 0),
                                                     redBin: RGBLBin(0, 0, 0, 1),
                                                     greenBin: RGBLBin(0, 0, 0, 2),
                                                     blueBin: RGBLBin(0, 0, 0, 1)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(3, 2, 3, 2))
            
            histogramBuffer.release()
        }
    }
    
    /*
     All 4 pixels of a mixed RGB color (60, 150, 157), gamma histogram
     */
    func testMixedRgbGamma() {
        // BGRA
        let pixelData: [UInt8] = [
            157, 150, 60, 255,
            157, 150, 60, 255,
            157, 150, 60, 255,
            157, 150, 60, 255
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)

        let luminance = (0.2126 * 60/255.0
                            + 0.7152 * 150/255.0
                            + 0.0722 * 157/255.0)
        let luminanceBin = binIndex(luminance)
        
        // calculate gamma encoded histogram
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            histogramBuffer.dumpBufferContents()

            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [60: RGBLBin(4, 0, 0, 0),
                                                     150: RGBLBin(0, 4, 0, 0),
                                                     157: RGBLBin(0, 0, 4, 0),
                                                     luminanceBin: RGBLBin(0, 0, 0, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
    }
    
    /*
     All 4 pixels of a mixed RGB color (60, 150, 157), linear histogram
     */
    func testMixedRgbLinear() {
        // BGRA
        let pixelData: [UInt8] = [
            157, 150, 60, 255,
            157, 150, 60, 255,
            157, 150, 60, 255,
            157, 150, 60, 255
        ]
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)

        let redBin = binIndex(linearize(60/255.0))
        let greenBin = binIndex(linearize(150/255.0))
        let blueBin = binIndex(linearize(157/255.0))
        
        let luminance = (0.2126 * linearize(60/255.0)
                            + 0.7152 * linearize(150/255.0)
                            + 0.0722 * linearize(157/255.0))
        let luminanceBin = binIndex(luminance)
        
        // calculate gamma encoded histogram
        histogramGenerator.process(texture: texture, isLinear: true) { histogramBuffer in
            histogramBuffer.dumpBufferContents()

            self.checkHistogramBuffer(histogram: histogramBuffer,
                                      expectedBins: [redBin: RGBLBin(4, 0, 0, 0),
                                                     greenBin: RGBLBin(0, 4, 0, 0),
                                                     blueBin: RGBLBin(0, 0, 4, 0),
                                                     luminanceBin: RGBLBin(0, 0, 0, 4)])
            
            XCTAssertEqual(histogramBuffer.maxBinValues, RGBLBin(4, 4, 4, 4))
            
            histogramBuffer.release()
        }
    }


    static var allTests = [
        ("testWhite", testWhite),
        ("testBlack", testBlack),
        ("test18Gray", test18Gray),
        ("testPureRgb", testPureRgb),
        ("testMixedRgbGamma", testMixedRgbGamma),
        ("testMixedRgbLinear", testMixedRgbLinear),
    ]
}
