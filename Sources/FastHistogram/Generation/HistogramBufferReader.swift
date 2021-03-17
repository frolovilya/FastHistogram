import Foundation
import MetalKit
import CShaderHeader

let RGBL_4: Int = 4

class HistogramBufferReader {
    let histogramBuffer: MTLBuffer
    let maxBinValueBuffer: MTLBuffer
    let binsCount: simd_uint1
    
    init(histogramBuffer: MTLBuffer,
         maxBinValueBuffer: MTLBuffer,
         binsCount: simd_uint1) {
        self.histogramBuffer = histogramBuffer
        self.maxBinValueBuffer = maxBinValueBuffer
        self.binsCount = binsCount
    }
    
    func getPointer() -> UnsafeMutablePointer<simd_uint1> {
        return histogramBuffer.contents().bindMemory(to: simd_uint1.self,
                                                     capacity: Int(binsCount) * RGBL_4)
    }
    
    func getBin(index: simd_uint1) -> simd_uint4 {
        let pointer = getPointer()
        
        let red = pointer.advanced(by: Int(index) * RGBL_4 + Int(Red.rawValue)).pointee
        let green = pointer.advanced(by: Int(index) * RGBL_4 + Int(Green.rawValue)).pointee
        let blue = pointer.advanced(by: Int(index) * RGBL_4 + Int(Blue.rawValue)).pointee
        let luminance = pointer.advanced(by: Int(index) * RGBL_4 + Int(Luminance.rawValue)).pointee
        
        return simd_uint4(red, green, blue, luminance)
    }
    
    func printBufferContents() -> Void {
        print("bins = ")
        for i in 0..<binsCount {
            let rgbl = getBin(index: i)
            print("\(i): (\(rgbl[0]), \(rgbl[1]), \(rgbl[2]), \(rgbl[3]))")
        }
        
        let maxBinValuePointer = maxBinValueBuffer.contents().bindMemory(to: simd_uint4.self,
                                                                         capacity: 1)
        print("maxBinValues = \(maxBinValuePointer.pointee)")
    }
    
}
