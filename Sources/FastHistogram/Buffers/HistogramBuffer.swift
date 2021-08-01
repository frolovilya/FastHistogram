import MetalKit
import CShaderHeader

/**
 Buffer that holds generated histogram bins.
 Wraps `MTLBuffer` to ease access to RGBL data.
 */
public final class HistogramBuffer: PoolResource {
    
    /**
     Underlying metal buffer.
     
     Memory layout is the following: [4 max bin values: four 32-bit uints] + [RGBL bins: four 32-bit uints] * binsCount.
     */
    let metalBuffer: MTLBuffer
    
    /// Number of RGBL bins in this buffer.
    public let binsCount: Int
    
    init(gpuHandler: GPUHandler, binsCount: Int) throws {
        guard binsCount > 0 else { throw GPUOperationError.illegalArgument }
        self.binsCount = binsCount
        
        guard let metalBuffer = gpuHandler.device.makeBuffer(length: HistogramBuffer.sizeBytes(binsCount: binsCount),
                                                             options: .storageModeShared)
        else { throw GPUOperationError.initializationError }
        self.metalBuffer = metalBuffer
    }
    
    static func makePool(gpuHandler: GPUHandler, binsCount: Int, poolSize: Int) throws -> SharedResourcePool<HistogramBuffer> {
        guard binsCount > 0 else { throw GPUOperationError.illegalArgument }
        guard poolSize > 0 else { throw GPUOperationError.illegalArgument }

        var histogramBuffers: [HistogramBuffer] = []
        for _ in 0..<poolSize {
            histogramBuffers.append(try HistogramBuffer(gpuHandler: gpuHandler, binsCount: binsCount))
        }
        return SharedResourcePool(resources: histogramBuffers)
    }
    
    /// Pool that owns this buffer instance, if any.
    public weak var pool: SharedResourcePool<HistogramBuffer>?

    /// Release this buffer instance back to the shared resource pool.
    public func release() -> Void {
        pool?.release(resource: self)
    }
    
    static func sizeBytes(binsCount: Int) -> Int {
        return MemoryLayout<RGBLBinCell>.stride * RGBL_4 * (binsCount + 1)
    }
    
    /// Number of `RGBLBinCell`s inside this histogram buffer.
    var capacity: Int {
        return (binsCount + 1) * RGBL_4
    }
    
    private func newPointer() -> UnsafeMutablePointer<RGBLBinCell> {
        return metalBuffer.contents().bindMemory(to: RGBLBinCell.self,
                                                 capacity: capacity)
    }
    
    /**
     Returns Red, Green, Blue and Luminance data at a given `index`.
     
     Bin data is not normalized. Divide by `maxBinValues` in order to get normalized RGBL.
     
     - Parameter index: bin number.
     - Returns: `RGBLBin` or `nil` if given `index` is incorrect.
     */
    public func getBin(index: Int) -> RGBLBin? {
        guard index >= 0 && index < binsCount else { return nil }
        
        let pointer = newPointer()
        
        let red = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Red.rawValue)).pointee
        let green = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Green.rawValue)).pointee
        let blue = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Blue.rawValue)).pointee
        let luminance = pointer.advanced(by: (index + 1) * RGBL_4 + Int(Luminance.rawValue)).pointee
        
        return RGBLBin(red, green, blue, luminance)
    }
    
    /**
     Max bin cell values for each RGBL channel in this histogram.
     
     Use this data for RGBL normalization.
     */
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
            if let rgbl = getBin(index: i) {
                print("\(i): (\(rgbl[0]), \(rgbl[1]), \(rgbl[2]), \(rgbl[3]))")
            }
        }
        
        print("maxBinValues = \(maxBinValues)")
    }
    
}
