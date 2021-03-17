import Foundation
import MetalKit
import Combine
import CShaderHeader

public class HistogramRenderer: NSObject, MTKViewDelegate {
    
    public let view: MTKView
    
    private let gpuHandler: GPUHandler
    private let renderPipelineState: MTLRenderPipelineState
    
    private var histogramBuffer: MTLBuffer!
    private var maxBinValueBuffer: MTLBuffer!
    
    private var barVertices: [simd_float2] = [
        [0, 0], [0, 1], [1, 1], // left triangle
        [0, 0], [1, 0], [1, 1]  // right triangle
    ]
    
    private var binsCount: simd_uint1
    private var layerColors: [simd_float4]
    
    private var updatePublisherCancellable: AnyCancellable?

    public init(gpuHandler: GPUHandler,
                view: MTKView,
                binsCount: simd_uint1,
                layerColors: [simd_float4],
                histogramBuffer: MTLBuffer,
                maxBinValueBuffer: MTLBuffer) throws {
        self.gpuHandler = gpuHandler
        self.view = view
        self.binsCount = binsCount
        self.layerColors = layerColors
        
        self.histogramBuffer = histogramBuffer
        self.maxBinValueBuffer = maxBinValueBuffer
        
        // init render pipeline states
        renderPipelineState = try HistogramRenderer.initRenderPipelineState(device: gpuHandler.device,
                                                                            library: gpuHandler.library)
                
        // setup view
        super.init()
        self.view.device = gpuHandler.device
        self.view.delegate = self
    }
    
    private static func initRenderPipelineState(device: MTLDevice, library: MTLLibrary?) throws -> MTLRenderPipelineState {
        let vertexFunction = library?.makeFunction(name: "histogram_bar_vertex")
        let fragmentFunction = library?.makeFunction(name: "histogram_bar_fragment")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        return try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    private func renderingPass(view: MTKView) -> Void {
        // setup rendering encoder
        guard let commandBuffer = gpuHandler.commandQueue.makeCommandBuffer(), // stores GPU commands
              let renderPassDescription = view.currentRenderPassDescriptor, // render destinations data
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescription)
        else {
            print("Unable to set up render command encoder")
            return
        }

        commandEncoder.setRenderPipelineState(renderPipelineState)
        
        // render bar
        commandEncoder.setVertexBytes(&barVertices,
                                      length: MemoryLayout<simd_float2>.stride * barVertices.count,
                                      index: Int(HistogramVertexInputIndexVertices.rawValue))
        
        commandEncoder.setVertexBuffer(histogramBuffer,
                                       offset: 0,
                                       index: Int(HistogramVertexInputIndexHistogramBuffer.rawValue))
        
        commandEncoder.setVertexBytes(&binsCount,
                                      length: MemoryLayout<simd_uint1>.stride,
                                      index: Int(HistogramVertexInputIndexBinsCount.rawValue))
        
        commandEncoder.setVertexBuffer(maxBinValueBuffer,
                                       offset: 0,
                                       index: Int(HistogramVertexInputIndexMaxBinValue.rawValue))

        commandEncoder.setVertexBytes(&layerColors,
                                      length: MemoryLayout<simd_float4>.stride * layerColors.count,
                                      index: Int(HistogramVertexInputIndexColors.rawValue))

        // commandEncoder.setTriangleFillMode(.lines)
        
        commandEncoder.drawPrimitives(type: .triangle,
                                      vertexStart: 0,
                                      vertexCount: barVertices.count,
                                      instanceCount: Int(binsCount) * RGBL_4)
                        
        // finish commands encoding
        commandEncoder.endEncoding()

        // present view
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        // commit commands to GPU
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
        renderingPass(view: view)
    }

}
