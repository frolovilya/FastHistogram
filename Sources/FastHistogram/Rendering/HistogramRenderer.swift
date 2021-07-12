import Foundation
import MetalKit
import Combine
import CShaderHeader

/**
 Render RGBL histogram data on the GPU.
 */
public class HistogramRenderer: NSObject, MTKViewDelegate {
    
    private static var barVertices: [simd_float2] = [
        [0, 0], [0, 1], [1, 1], // left triangle
        [0, 0], [1, 0], [1, 1]  // right triangle
    ]
    
    private let gpuHandler: GPUHandler
    private let renderPipelineState: MTLRenderPipelineState
    private var histogramView: HistogramView!

    private var histogramBuffer: HistogramBuffer?
    private var enabledRGBLLayers: [Bool] = [true, true, true, true]
    private var binsCount: Int
    private var layerColors: [RGBAColor]
    
    private var updatePublisherCancellable: AnyCancellable?
    
    private let renderingQueue = DispatchQueue(label: "HistogramRendererQueue")
    
    #if os(OSX)
    /// Renderer's underlying view
    public var view: some NSView {
        histogramView.view
    }
    #else
    /// Renderer's underlying view
    public var view: some UIView {
        histogramView.view
    }
    #endif
    
    /**
     Initiate new histogram renderer instance.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter binsCount: number of histogram bins to draw.
     - Parameter layerColors: vector of four RGB colors to represent RGBL layers.
     - Parameter backgroundColor: histogram's background color.
     */
    public init(gpuHandler: GPUHandler,
                binsCount: Int,
                layerColors: [RGBAColor],
                backgroundColor: RGBAColor) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        self.layerColors = layerColors
        
        // init render pipeline states
        renderPipelineState = try HistogramRenderer.initRenderPipelineState(device: gpuHandler.device,
                                                                            library: gpuHandler.library)
        
        super.init()

        // setup view
        histogramView = HistogramView(device: gpuHandler.device,
                                      delegate: self,
                                      backgroundColor: backgroundColor)
    }
    
    private static func initRenderPipelineState(device: MTLDevice, library: MTLLibrary?) throws -> MTLRenderPipelineState {
        let vertexFunction = library?.makeFunction(name: "histogramBarVertex")
        let fragmentFunction = library?.makeFunction(name: "histogramBarFragment")
        
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
    
    /**
     Draw histogram data from `HistogramBuffer`.
     
     - Parameters:
        - histogramBuffer: buffer with histogram data. Note that the buffer will be auto-released when histogram is rendered.
        - showRed: show Red layer.
        - showGreen: show Green layer.
        - showBlue: show Blue layer.
        - showLuminance: show Luminance layer.
     */
    public func draw(histogramBuffer: HistogramBuffer,
                     showRed: Bool = true,
                     showGreen: Bool = true,
                     showBlue: Bool = true,
                     showLuminance: Bool = true) -> Void {
        renderingQueue.async {
            self.enabledRGBLLayers = [showRed, showGreen, showBlue, showLuminance]
            self.histogramBuffer = histogramBuffer
            self.histogramView.view.draw()
        }
    }
    
    func renderingPass(view: MTKView) -> Void {
        guard let histogramBuffer = self.histogramBuffer else { return }
        
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
        commandEncoder.setVertexBytes(&HistogramRenderer.barVertices,
                                      length: MemoryLayout<simd_float2>.stride * HistogramRenderer.barVertices.count,
                                      index: Int(HistogramVertexInputIndexVertices.rawValue))
        
        commandEncoder.setVertexBuffer(histogramBuffer.metalBuffer,
                                       offset: 0,
                                       index: Int(HistogramVertexInputIndexHistogramBuffer.rawValue))
        
        commandEncoder.setVertexBytes(&binsCount,
                                      length: MemoryLayout<simd_uint1>.stride,
                                      index: Int(HistogramVertexInputIndexBinsCount.rawValue))
        
        commandEncoder.setVertexBytes(&layerColors,
                                      length: MemoryLayout<RGBAColor>.stride * layerColors.count,
                                      index: Int(HistogramVertexInputIndexColors.rawValue))
        
        commandEncoder.setVertexBytes(&enabledRGBLLayers,
                                      length: MemoryLayout<Bool>.stride * RGBL_4,
                                      index: Int(HistogramVertexInputIndexEnabledLayers.rawValue))

        // commandEncoder.setTriangleFillMode(.lines)
        
        commandEncoder.drawPrimitives(type: .triangle,
                                      vertexStart: 0,
                                      vertexCount: HistogramRenderer.barVertices.count,
                                      instanceCount: binsCount * RGBL_4)
        
        commandBuffer.addCompletedHandler { _ in
            histogramBuffer.release()
        }
        
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
