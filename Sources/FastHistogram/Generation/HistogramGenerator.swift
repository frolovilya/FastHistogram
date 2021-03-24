import Foundation
import MetalKit
import Combine
import CShaderHeader

public class HistogramGenerator {
    
    private let gpuHandler: GPUHandler
    private var binsCount: Int
    private let histogramBufferPool: SharedResourcePool<HistogramBuffer>

    private let zeroHistogramBufferComputePipelineState: MTLComputePipelineState
    private let generateHistogramComputePipelineState: MTLComputePipelineState
    
    public init(gpuHandler: GPUHandler,
                binsCount: Int) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        
        // init compute pipeline states
        self.generateHistogramComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "generateHistogram")
        self.zeroHistogramBufferComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "zeroHistogramBuffer")

        // init result buffer pool
        self.histogramBufferPool = try HistogramBuffer.makePool(device: gpuHandler.device,
                                                                binsCount: binsCount,
                                                                poolSize: 3)
    }
    
    private static func initComputePipelineState(gpuHandler: GPUHandler, functionName: String) throws -> MTLComputePipelineState {
        if let computeFunction = gpuHandler.library.makeFunction(name: functionName) {
            return try gpuHandler.device.makeComputePipelineState(function: computeFunction)
        } else {
            throw GPUOperationError.initializationError
        }
    }

    public func process(texture: HistogramTexture,
                        isLinear: Bool,
                        onCompleted: @escaping (HistogramBuffer) -> Void) -> Void {
        
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
        
        let gridSize = MTLSizeMake(histogramBuffer.capacity, 1, 1)
        let threadsPerGroup = MTLSizeMake(min(zeroHistogramBufferComputePipelineState.maxTotalThreadsPerThreadgroup,
                                              histogramBuffer.capacity), 1, 1)
        
        commandEncoder.dispatchThreads(gridSize,
                                       threadsPerThreadgroup: threadsPerGroup)
    }

    private func encodeGenerateHistogram(commandEncoder: MTLComputeCommandEncoder,
                                         texture: MTLTexture,
                                         size: MTLSize,
                                         isLinear: Bool) {
        commandEncoder.setComputePipelineState(generateHistogramComputePipelineState)

        // init buffers
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
        let threadsPerGroup = MTLSizeMake(w, h, 1)

        commandEncoder.dispatchThreads(size,
                                       threadsPerThreadgroup: threadsPerGroup)
    }

}
