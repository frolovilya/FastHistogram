import Foundation
import MetalKit
import Combine
import CShaderHeader

/**
 RGBL histogram generation on the GPU.
 */
public class HistogramGenerator {
    
    private let gpuHandler: GPUHandler
    private var binsCount: Int
    private let histogramBufferPool: SharedResourcePool<HistogramBuffer>

    private let zeroHistogramBufferComputePipelineState: MTLComputePipelineState
    private let generateHistogramComputePipelineState: MTLComputePipelineState
    
    /**
     Init new `HistogramGenerator` instance.
     
     - Parameter gpuHandler: `GPUHandler` instance
     - Parameter binsCount: Number of histogram bins this generator is going to produce
     - Parameter bufferPoolSize: Pool size for shared `HistogramBuffer` resources.
                                 This parameter defines max number of buffers to be shared between GPU and CPU in parallel.
     
     - Throws: `initializationError` if unable to initialize required GPU resources.
               `illegalArgument` if incorrect parameter values provided.
     */
    public init(gpuHandler: GPUHandler,
                binsCount: Int,
                bufferPoolSize: Int = 3) throws {
        
        guard binsCount > 0 else { throw GPUOperationError.illegalArgument }
        guard bufferPoolSize > 0 else { throw GPUOperationError.illegalArgument }
        
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        
        // init compute pipeline states
        self.generateHistogramComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "generateHistogram")
        self.zeroHistogramBufferComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "zeroHistogramBuffer")

        // init result buffer pool
        self.histogramBufferPool = try HistogramBuffer.makePool(gpuHandler: gpuHandler,
                                                                binsCount: binsCount,
                                                                poolSize: bufferPoolSize)
    }
    
    private static func initComputePipelineState(gpuHandler: GPUHandler,
                                                 functionName: String) throws -> MTLComputePipelineState {
        if let computeFunction = gpuHandler.library.makeFunction(name: functionName) {
            return try gpuHandler.device.makeComputePipelineState(function: computeFunction)
        } else {
            throw GPUOperationError.initializationError
        }
    }

    /**
     Generate histogram for `HistogramTexture` on the GPU and return `HistogramBuffer` instance when done.
     
     This method may wait for a next available `HistogramBuffer` instance from a buffer pool.
     Max concurrency level is defined by `bufferPoolSize` parameter to the `HistogramGenerator.init` constructor.
     
     - Parameter texture: `HistogramTexture` with image data to process
     - Parameter isLinear: If `false`, then Gamma-encoded histogram is generated (with gamma value 2.4).
                           When `true`, then linearized histogarm is generated.
     - Parameter onCompleted: Closure to be called when GPU finishes histogram generation.
     - Parameter buffer: Histogram data. Note that `HistogramBuffer` returned must be released to the pool by calling `.release()` method after you've done with it's processing.
     */
    public func process(texture: HistogramTexture,
                        isLinear: Bool,
                        onCompleted: @escaping (_ buffer: HistogramBuffer) -> Void) -> Void {
        
        let histogramBuffer = histogramBufferPool.nextResource
        
        // gpuHandler.startProgrammaticCapture()
        
        // setup compute encoder
        guard let commandBuffer = gpuHandler.commandQueue.makeCommandBuffer(), // stores GPU commands
              let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            print("Unable to set up compute command encoder")
            return
        }
        
        encodeZeroHistogramBuffer(commandEncoder: commandEncoder, histogramBuffer: histogramBuffer)
        encodeGenerateHistogram(commandEncoder: commandEncoder,
                                texture: texture.metalTexture,
                                size: texture.size,
                                isLinear: isLinear)
        
        commandBuffer.addCompletedHandler { _ in
            texture.release()
            onCompleted(histogramBuffer)
        }
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        // gpuHandler.stopProgrammaticCapture()
    }
    
    private func encodeZeroHistogramBuffer(commandEncoder: MTLComputeCommandEncoder, histogramBuffer: HistogramBuffer) {
        commandEncoder.setComputePipelineState(zeroHistogramBufferComputePipelineState)

        commandEncoder.setBuffer(histogramBuffer.metalBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexHistogramBuffer.rawValue))
        
        commandEncoder.setBytes(&binsCount,
                                length: MemoryLayout<simd_uint1>.stride,
                                index: Int(HistogramGeneratorInputIndexBinsCount.rawValue))
        
        // init grid size
        let w = min(histogramBuffer.capacity, zeroHistogramBufferComputePipelineState.threadExecutionWidth)
        let threadsPerThreadgroup = MTLSizeMake(w, 1, 1)
        let threadgroupsPerGrid = MTLSizeMake((histogramBuffer.capacity + w - 1) / w, 1, 1)
        
        if (gpuHandler.supportsNonUniformThreadgroupSize) {
            let gridSize = MTLSizeMake(histogramBuffer.capacity, 1, 1)
            commandEncoder.dispatchThreads(gridSize,
                                           threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid,
                                                threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }

    private func encodeGenerateHistogram(commandEncoder: MTLComputeCommandEncoder,
                                         texture: MTLTexture,
                                         size: MTLSize,
                                         isLinear: Bool) {
        commandEncoder.setComputePipelineState(generateHistogramComputePipelineState)

        commandEncoder.setTexture(texture,
                                  index: Int(HistogramGeneratorInputIndexTexture.rawValue))
        
        commandEncoder.setBytes(&binsCount,
                                length: MemoryLayout<simd_uint1>.stride,
                                index: Int(HistogramGeneratorInputIndexBinsCount.rawValue))
        
        var _isLinear = isLinear
        commandEncoder.setBytes(&_isLinear,
                                length: MemoryLayout<simd_bool>.stride,
                                index: Int(HistogramGeneratorInputIndexIsLinear.rawValue))
        
        // Histogram buffer must be already set by other methods using this command encoder

        // init grid size
        let w = min(size.width, generateHistogramComputePipelineState.threadExecutionWidth)
        let h = min(size.height, generateHistogramComputePipelineState.maxTotalThreadsPerThreadgroup / w)
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadgroupsPerGrid = MTLSizeMake((size.width + w - 1) / w,
                                              (size.height + h - 1) / h,
                                              1)

        if (gpuHandler.supportsNonUniformThreadgroupSize) {
            commandEncoder.dispatchThreads(size,
                                           threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid,
                                                threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }

}
