import Foundation
import MetalKit
import Combine
import CShaderHeader

public class HistogramGenerator {
    
    private let gpuHandler: GPUHandler
    
    private let zeroHistogramBufferComputePipelineState: MTLComputePipelineState
    private let generateHistogramComputePipelineState: MTLComputePipelineState
    
    private var binsCount: Int

    public let histogramBuffer: HistogramBuffer
    
    public init(gpuHandler: GPUHandler,
                binsCount: Int) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        
        // init compute pipeline states
        self.generateHistogramComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "generateHistogram")
        self.zeroHistogramBufferComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "zeroHistogramBuffer")
                
        // init result buffer
        self.histogramBuffer = try HistogramBuffer(device: gpuHandler.device, binsCount: binsCount)
    }
    
    private static func initComputePipelineState(gpuHandler: GPUHandler, functionName: String) throws -> MTLComputePipelineState {
        if let computeFunction = gpuHandler.library.makeFunction(name: functionName) {
            return try gpuHandler.device.makeComputePipelineState(function: computeFunction)
        } else {
            throw GPUOperationError.initializationError
        }
    }
    
    public func process(texture: MTLTexture,
                        isLinear: Bool) -> Void {
        histogramGenerationPass(texture: texture,
                                size: MTLSizeMake(texture.width, texture.height, texture.depth),
                                isLinear: isLinear)
    }
    
    private func histogramGenerationPass(texture: MTLTexture,
                                         size: MTLSize,
                                         isLinear: Bool) -> Void {
        
//        gpuHandler.startProgrammaticCapture()
        
        // setup compute encoder
        guard let commandBuffer = gpuHandler.commandQueue.makeCommandBuffer(), // stores GPU commands
              let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            print("Unable to set up compute command encoder")
            return
        }
        
        encodeZeroHistogramBuffer(commandEncoder: commandEncoder)
        encodeGenerateHistogram(commandEncoder: commandEncoder, texture: texture, size: size, isLinear: isLinear)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
//        gpuHandler.stopProgrammaticCapture()
        
        commandBuffer.waitUntilCompleted()
    }
    
    private func encodeZeroHistogramBuffer(commandEncoder: MTLComputeCommandEncoder) {
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
