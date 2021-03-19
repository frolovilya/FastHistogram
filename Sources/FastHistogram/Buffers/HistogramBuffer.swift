import MetalKit
import CShaderHeader

public class HistogramBuffer {
    
    public let metalBuffer: MTLBuffer
    public let binsCount: Int
    
    init(device: MTLDevice, binsCount: Int) throws {
        self.binsCount = binsCount
        
        guard let metalBuffer = device.makeBuffer(length: HistogramBuffer.sizeBytes(binsCount: binsCount),
                                                  options: .storageModeShared)
        else { throw GPUOperationError.initializationError }
        self.metalBuffer = metalBuffer
    }
    
    static func sizeBytes(binsCount: Int) -> Int {
        return MemoryLayout<RGBLBinCell>.stride * RGBL_4 * binsCount
    }
    
    var capacity: Int {
        return binsCount * RGBL_4
    }
    
    private func newPointer() -> UnsafeMutablePointer<RGBLBinCell> {
        return metalBuffer.contents().bindMemory(to: RGBLBinCell.self,
                                                 capacity: capacity)
    }
    
    public func getBin(index: Int) -> RGBLBin {
        let pointer = newPointer()
        
        let red = pointer.advanced(by: index * RGBL_4 + Int(Red.rawValue)).pointee
        let green = pointer.advanced(by: index * RGBL_4 + Int(Green.rawValue)).pointee
        let blue = pointer.advanced(by: index * RGBL_4 + Int(Blue.rawValue)).pointee
        let luminance = pointer.advanced(by: index * RGBL_4 + Int(Luminance.rawValue)).pointee
        
        return RGBLBin(red, green, blue, luminance)
    }
    
    func dumpBufferContents() -> Void {
        print("bins = ")
        for i in 0..<binsCount {
            let rgbl = getBin(index: i)
            print("\(i): (\(rgbl[0]), \(rgbl[1]), \(rgbl[2]), \(rgbl[3]))")
        }
    }
    
}
