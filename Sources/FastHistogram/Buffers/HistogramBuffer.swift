import MetalKit
import CShaderHeader

public final class HistogramBuffer: PoolResource {
    
    // [4 max bin values][histogram bins]
    public let metalBuffer: MTLBuffer
    public let binsCount: Int
    
    init(device: MTLDevice, binsCount: Int) throws {
        self.binsCount = binsCount
        
        guard let metalBuffer = device.makeBuffer(length: HistogramBuffer.sizeBytes(binsCount: binsCount),
                                                  options: .storageModeShared)
        else { throw GPUOperationError.initializationError }
        self.metalBuffer = metalBuffer
    }
    
    static func makePool(device: MTLDevice, binsCount: Int, poolSize: Int) throws -> SharedResourcePool<HistogramBuffer> {
        var histogramBuffers: [HistogramBuffer] = []
        for _ in 0..<poolSize {
            histogramBuffers.append(try HistogramBuffer(device: device, binsCount: binsCount))
        }
        return SharedResourcePool(resources: histogramBuffers)
    }
    
    public weak var pool: SharedResourcePool<HistogramBuffer>?

    public func release() -> Void {
        pool?.release(resource: self)
    }
    
    static func sizeBytes(binsCount: Int) -> Int {
        return MemoryLayout<RGBLBinCell>.stride * RGBL_4 * (binsCount + 1)
    }
    
    var capacity: Int {
        return (binsCount + 1) * RGBL_4
    }
    
    private func newPointer() -> UnsafeMutablePointer<RGBLBinCell> {
        return metalBuffer.contents().bindMemory(to: RGBLBinCell.self,
                                                 capacity: capacity)
    }
    
    public func getBin(index: Int) -> RGBLBin {
        let pointer = newPointer()
        
        let red = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Red.rawValue)).pointee
        let green = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Green.rawValue)).pointee
        let blue = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Blue.rawValue)).pointee
        let luminance = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Luminance.rawValue)).pointee
        
        return RGBLBin(red, green, blue, luminance)
    }
    
    public var maxBinValues: RGBLBin {
        let pointer = newPointer()
        
        return RGBLBin(pointer.pointee,
                       pointer.advanced(by: 1).pointee,
                       pointer.advanced(by: 2).pointee,
                       pointer.advanced(by: 3).pointee)
    }
    
    func dumpBufferContents() -> Void {
        print("bins = ")
        for i in 0..<binsCount {
            let rgbl = getBin(index: i)
            print("\(i): (\(rgbl[0]), \(rgbl[1]), \(rgbl[2]), \(rgbl[3]))")
        }
        
        print("maxBinValues = \(maxBinValues)")
    }
    
}
