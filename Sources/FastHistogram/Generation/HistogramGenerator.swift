import Foundation
import MetalKit
import Combine
import CShaderHeader

public class HistogramGenerator {
    
    private let gpuHandler: GPUHandler
    
    private let zeroHistogramBufferComputePipelineState: MTLComputePipelineState
    private let zeroMaxBinValueBufferComputePipelineState: MTLComputePipelineState
    private let generateHistogramComputePipelineState: MTLComputePipelineState
    
    private var binsCount: Int

    public let histogramBuffer: HistogramBuffer
    public let maxBinValueBuffer: MaxBinValueBuffer
    
    public init(gpuHandler: GPUHandler,
                binsCount: Int) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        
        // init compute pipeline states
        self.generateHistogramComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "generateHistogram")
        self.zeroHistogramBufferComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "zeroHistogramBuffer")
        self.zeroMaxBinValueBufferComputePipelineState = try HistogramGenerator.initComputePipelineState(gpuHandler: gpuHandler, functionName: "zeroMaxBinValueBuffer")
                
        // init result buffers
        self.histogramBuffer = try HistogramBuffer(device: gpuHandler.device, binsCount: binsCount)
        self.maxBinValueBuffer = try MaxBinValueBuffer(device: gpuHandler.device)
    }
    
    private static func initComputePipelineState(gpuHandler: GPUHandler, functionName: String) throws -> MTLComputePipelineState {
        if let computeFunction = gpuHandler.library.makeFunction(name: functionName) {
            return try gpuHandler.device.makeComputePipelineState(function: computeFunction)
        } else {
            throw GPUOperationError.initializationError
        }
    }
    
    public func process(cgImage: CGImage,
                        isLinear: Bool) -> Void {
        if let texture = try? MTKTextureLoader(device: gpuHandler.device).newTexture(cgImage: cgImage, options: nil) {
            histogramGenerationPass(texture: texture,
                                    size: MTLSizeMake(cgImage.width, cgImage.height, 1),
                                    isLinear: isLinear)
        } else {
            print("Unable to generate texture from input image")
        }
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
        encodeZeroMaxBinValueBuffer(commandEncoder: commandEncoder)
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
    
    private func encodeZeroMaxBinValueBuffer(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setComputePipelineState(zeroMaxBinValueBufferComputePipelineState)

        commandEncoder.setBuffer(maxBinValueBuffer.metalBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexMaxBinValueBuffer.rawValue))

        let gridSize = MTLSizeMake(maxBinValueBuffer.capacity, 1, 1)
        let threadsPerGroup = MTLSizeMake(min(zeroMaxBinValueBufferComputePipelineState.maxTotalThreadsPerThreadgroup,
                                              maxBinValueBuffer.capacity), 1, 1)
        
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
        
        commandEncoder.setBuffer(histogramBuffer.metalBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexHistogramBuffer.rawValue))
        
        commandEncoder.setBuffer(maxBinValueBuffer.metalBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexMaxBinValueBuffer.rawValue))

        // init grid size
//        let w = generateHistogramComputePipelineState.threadExecutionWidth
//        let h = generateHistogramComputePipelineState.maxTotalThreadsPerThreadgroup / w
//        let threadsPerGroup = MTLSizeMake(w, h, 1)
        let threadsPerGroup = MTLSizeMake(2, 2, 1)

        commandEncoder.dispatchThreads(size,
                                       threadsPerThreadgroup: threadsPerGroup)
    }

}
