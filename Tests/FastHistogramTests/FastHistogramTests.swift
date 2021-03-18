import XCTest
import simd
import AppKit
@testable import FastHistogram

final class FastHistogramTests: XCTestCase {
    
    private static let binsCount: Int = 256
    
    var gpuHandler: GPUHandler!
    var histogramGenerator: HistogramGenerator!
    
    override func setUpWithError() throws {
        gpuHandler = try GPUHandler()
        histogramGenerator = try HistogramGenerator(gpuHandler: gpuHandler,
                                                    binsCount: FastHistogramTests.binsCount)
    }
    
    private func getImage(name: String) -> CGImage? {
        guard let imageURL = Bundle.module.url(forResource: name, withExtension: "jpg")
        else { return nil }
        
        guard let image = NSImage(contentsOf: imageURL)
        else { return nil }
        
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        
        return image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
    }

    private func linearize(_ value: Double) -> Double {
        pow((value + 0.055) / 1.055, 2.4)
    }
    
    private func binIndex(_ value: Double) -> Int {
        Int(value * Double(FastHistogramTests.binsCount - 1))
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
     All 4 pixels of white RGB(255, 255, 255) color.
     R: 255 - 1
     G: 255 - 1
     B: 255 - 1
     L: 255 - 1
     */
    func testWhite() {
        guard let image = getImage(name: "white_2x2")
        else {
            XCTFail()
            return
        }
        
        histogramGenerator.process(cgImage: image, isLinear: false)
        histogramGenerator.histogramBuffer.dumpBufferContents()
        histogramGenerator.maxBinValueBuffer.dumpBufferContents()
        
        checkHistogramBuffer(histogram: histogramGenerator.histogramBuffer,
                             expectedBins: [FastHistogramTests.binsCount - 1: RGBLBin(4, 4, 4, 4)])
    }
    
    /*
     All 4 pixels of black RGB(0, 0, 0) color.
     R: 0 - 4
     G: 0 - 4
     B: 0 - 4
     L: 0 - 4
     */
    func testBlack() {
        guard let image = getImage(name: "black_2x2")
        else {
            XCTFail()
            return
        }
        
        histogramGenerator.process(cgImage: image, isLinear: false)
        histogramGenerator.histogramBuffer.dumpBufferContents()
        histogramGenerator.maxBinValueBuffer.dumpBufferContents()
        
        checkHistogramBuffer(histogram: histogramGenerator.histogramBuffer,
                             expectedBins: [0: RGBLBin(4, 4, 4, 4)])
    }
    
    /*
     All 4 pixels of gray RGB(119, 119, 119) color.
     
     Assuming 119 is gamma encoded (with gamma=2.4), it's gamma luminance is ~47%.
     Linearized luminance is:
     (119/255)^2.4 = ~16%
     
     */
    func test18Gray() {
        guard let image = getImage(name: "18_gray_2x2")
        else {
            XCTFail()
            return
        }
        
        // calculate gamma encoded histogram
        histogramGenerator.process(cgImage: image, isLinear: false)
        histogramGenerator.histogramBuffer.dumpBufferContents()
        histogramGenerator.maxBinValueBuffer.dumpBufferContents()
        
        let gammaEncodedBinIndex = 119
        checkHistogramBuffer(histogram: histogramGenerator.histogramBuffer,
                             expectedBins: [gammaEncodedBinIndex: RGBLBin(4, 4, 4, 4)])
        
        // calculate linearized histogram
        histogramGenerator.process(cgImage: image, isLinear: true)
        histogramGenerator.histogramBuffer.dumpBufferContents()
        histogramGenerator.maxBinValueBuffer.dumpBufferContents()

        let linearizedBinIndex = binIndex(linearize(119.0/255))
        checkHistogramBuffer(histogram: histogramGenerator.histogramBuffer,
                             expectedBins: [linearizedBinIndex: RGBLBin(4, 4, 4, 4)])
    }
    
    /*
     4 pixels with the following gamma RGB values:
     0 0 --- 0.0  1.0 0.004  Green
     0 1 --- 0.0  0.0 0.99   Blue
     1 0 --- 0.99 0.0 0.0    Red
     1 1 --- 0.0  1.0 0.0    Green
     
     Since these aren't gray colors, using the following perception coefficients to get luminance:
     (0.2126 * r + 0.7152 * g + 0.0722 * b)
     */
    func testRgb() {
        guard let image = getImage(name: "rggb_2x2")
        else {
            XCTFail()
            return
        }
        
        let redBin = binIndex(0.2126)
        let greenBin = binIndex(0.7152)
        let blueBin = binIndex(0.0722)
        
        // calculate gamma encoded histogram
        histogramGenerator.process(cgImage: image, isLinear: false)
        histogramGenerator.histogramBuffer.dumpBufferContents()
        histogramGenerator.maxBinValueBuffer.dumpBufferContents()

        checkHistogramBuffer(histogram: histogramGenerator.histogramBuffer,
                             expectedBins: [0: RGBLBin(3, 2, 2, 0),
                                            1: RGBLBin(0, 0, 1, 0), // blue 0.004
                                            254: RGBLBin(1, 0, 1, 0), // red, blue ~0.99
                                            255: RGBLBin(0, 2, 0, 0), // green 1
                                            redBin: RGBLBin(0, 0, 0, 1),
                                            greenBin: RGBLBin(0, 0, 0, 2),
                                            blueBin: RGBLBin(0, 0, 0, 1)])
        
    }

    static var allTests = [
        ("testWhite", testWhite),
        ("testBlack", testBlack),
        ("test18Gray", test18Gray),
    ]
}
