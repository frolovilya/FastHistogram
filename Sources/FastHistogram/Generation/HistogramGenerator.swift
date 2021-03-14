import Foundation
import MetalKit
import Combine
import CShaderHeader

public class HistogramGenerator {
    
    private let gpuHandler: GPUHandler
    private let computePipelineState: MTLComputePipelineState
    
    private var binsCount: simd_uint1

    // uint * binsCount
    public let histogramBuffer: MTLBuffer
    // uint * 4
    public let maxBinValueBuffer: MTLBuffer
    
    public init(gpuHandler: GPUHandler,
                binsCount: simd_uint1) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        
        // init compute pipeline state
        guard let generateHistogramFunction = gpuHandler.library.makeFunction(name: "generate_histogram")
        else { throw GPUOperationError.initializationError }
        computePipelineState = try gpuHandler.device.makeComputePipelineState(function: generateHistogramFunction)
        
        // init result buffer
        guard let histogramBuffer = gpuHandler.device.makeBuffer(length: MemoryLayout<simd_uint1>.stride * Int(binsCount) * 4,
                                                                 options: .storageModeShared)
        else { throw GPUOperationError.initializationError }
        self.histogramBuffer = histogramBuffer
        
        guard let maxBinValueBuffer = gpuHandler.device.makeBuffer(length: MemoryLayout<simd_uint1>.stride * 4,
                                                                   options: .storageModeShared)
        else { throw GPUOperationError.initializationError }
        self.maxBinValueBuffer = maxBinValueBuffer
    }
    
    public func process(cgImage: CGImage) -> Void {
        if let texture = try? MTKTextureLoader(device: gpuHandler.device).newTexture(cgImage: cgImage, options: nil) {
            histogramGenerationPass(texture: texture,
                                    size: MTLSizeMake(cgImage.width, cgImage.height, 1),
                                    isLinear: false)
        } else {
            print("Unable to generate texture from input image")
        }
    }
    
    private func histogramGenerationPass(texture: MTLTexture,
                                         size: MTLSize,
                                         isLinear: simd_bool) -> Void {
        // setup compute encoder
        guard let commandBuffer = gpuHandler.commandQueue.makeCommandBuffer(), // stores GPU commands
              let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            print("Unable to set up compute command encoder")
            return
        }
        
        commandEncoder.setComputePipelineState(computePipelineState)

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
        
        commandEncoder.setBuffer(histogramBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexResultBuffer.rawValue))
        
        commandEncoder.setBuffer(maxBinValueBuffer,
                                 offset: 0,
                                 index: Int(HistogramGeneratorInputIndexMaxBinValue.rawValue))

        // init grid size
        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSizeMake(w, h, 1)

        commandEncoder.dispatchThreads(size,
                                       threadsPerThreadgroup: threadsPerGroup)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()

        printBufferContents()
    }
    
    private func printBufferContents() -> Void {
        let histogramPointer = histogramBuffer.contents().bindMemory(to: simd_uint1.self,
                                                                     capacity: Int(binsCount) * 4)
        
        var bins: [simd_uint1] = []
        for i in 0..<(binsCount * 4) {
            bins.append(histogramPointer.advanced(by: Int(i)).pointee)
        }
        print("bins = \(bins)")
        
        let maxBinValuePointer = maxBinValueBuffer.contents().bindMemory(to: simd_uint1.self, capacity: 4)
        var maxValues: [simd_uint1] = []
        for i in 0..<4 {
            maxValues.append(maxBinValuePointer.advanced(by: i).pointee)
        }
        print("maxBinValues = \(maxValues)")
    }
    
}
