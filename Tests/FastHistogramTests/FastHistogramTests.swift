import XCTest
import simd
import AppKit
@testable import FastHistogram

final class FastHistogramTests: XCTestCase {
    
    static let binsCount: simd_uint1 = 256
    
    var gpuHandler: GPUHandler!
    var histogramGenerator: HistogramGenerator!
    var bufferReader: HistogramBufferReader!
    
    override func setUpWithError() throws {
        gpuHandler = try GPUHandler()
        histogramGenerator = try HistogramGenerator(gpuHandler: gpuHandler,
                                                    binsCount: FastHistogramTests.binsCount)

        bufferReader = HistogramBufferReader(histogramBuffer: histogramGenerator.histogramBuffer,
                                             maxBinValueBuffer: histogramGenerator.maxBinValueBuffer,
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
        bufferReader.printBufferContents()
        
        for index in 0..<(FastHistogramTests.binsCount - 1) {
            XCTAssertEqual(bufferReader.getBin(index: index), simd_uint4(0, 0, 0, 0))
        }
        XCTAssertEqual(bufferReader.getBin(index: FastHistogramTests.binsCount - 1), simd_uint4(4, 4, 4, 4))
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
        bufferReader.printBufferContents()
        
        XCTAssertEqual(bufferReader.getBin(index: 0), simd_uint4(4, 4, 4, 4))
        for index in 1..<FastHistogramTests.binsCount {
            XCTAssertEqual(bufferReader.getBin(index: index), simd_uint4(0, 0, 0, 0))
        }
    }
    
    // TODO: move to shared C code
    private func linearize(_ value: Double) -> Double {
        pow((value + 0.055) / 1.055, 2.4)
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
        bufferReader.printBufferContents()
        
        let gammaEncodedBinIndex: simd_uint1 = 119
        for index in 0..<FastHistogramTests.binsCount {
            XCTAssertEqual(bufferReader.getBin(index: index),
                           index == gammaEncodedBinIndex ? simd_uint4(4, 4, 4, 4) : simd_uint4(0, 0, 0, 0))
        }
        
        // calculate linearized histogram
        histogramGenerator.process(cgImage: image, isLinear: true)
        bufferReader.printBufferContents()
        
        let linearizedBinIndex: simd_uint1 = simd_uint1(Int(linearize(119.0/255) * Double(FastHistogramTests.binsCount - 1)))
        for index in 0..<FastHistogramTests.binsCount {
            XCTAssertEqual(bufferReader.getBin(index: index),
                           index == linearizedBinIndex ? simd_uint4(4, 4, 4, 4) : simd_uint4(0, 0, 0, 0))
        }
    }

    static var allTests = [
        ("testWhite", testWhite),
        ("testBlack", testBlack),
    ]
}
