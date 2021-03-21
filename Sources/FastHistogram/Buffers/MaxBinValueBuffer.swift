import Metal

public class MaxBinValueBuffer {
    
    public let metalBuffer: MTLBuffer
    
    init(device: MTLDevice) throws {
        guard let metalBuffer = device.makeBuffer(length: MaxBinValueBuffer.sizeBytes,
                                                  options: .storageModeShared)
        else { throw GPUOperationError.initializationError }

        self.metalBuffer = metalBuffer
    }

    static var sizeBytes: Int {
        return MemoryLayout<RGBLBinCell>.stride * RGBL_4
    }
    
    var capacity: Int {
        return RGBL_4
    }
    
    private func newPointer() -> UnsafeMutablePointer<RGBLBinCell> {
        return metalBuffer.contents().bindMemory(to: RGBLBinCell.self,
                                                 capacity: capacity)
    }
    
    func dumpBufferContents() -> Void {
        let pointer = newPointer()
        
        print("maxBinValues = (\(pointer.pointee), "
                + "\(pointer.advanced(by: 1).pointee), "
                + "\(pointer.advanced(by: 2).pointee), "
                + "\(pointer.advanced(by: 3).pointee))")
    }
    
    public var maxBinValues: RGBLBin {
        let pointer = newPointer()
        
        return RGBLBin(pointer.pointee,
                       pointer.advanced(by: 1).pointee,
                       pointer.advanced(by: 2).pointee,
                       pointer.advanced(by: 3).pointee)
    }
    
}
