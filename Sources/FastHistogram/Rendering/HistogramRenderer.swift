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
    private let renderTarget: HistogramRendererTarget

    private var histogramBuffer: HistogramBuffer?
    private var enabledRGBLLayers: [Bool] = [true, true, true, true]
    private var binsCount: Int
    private var layerColors: [RGBAFloatColor]
    
    private var updatePublisherCancellable: AnyCancellable?
    
    private let renderingQueue = DispatchQueue(label: "HistogramRendererQueue")
    
    /**
     Initiate new histogram renderer instance.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter renderTarget: render target to draw histogram into.
     - Parameter binsCount: number of histogram bins to draw.
     - Parameter layerColors: vector of four RGB colors to represent RGBL layers.
     */
    public init(gpuHandler: GPUHandler,
                renderTarget: HistogramRendererTarget,
                binsCount: Int,
                redLayerColor: RGBAFloatColor = RGBAFloatColor(1, 0, 0, 1),
                greenLayerColor: RGBAFloatColor = RGBAFloatColor(0, 1, 0, 1),
                blueLayerColor: RGBAFloatColor = RGBAFloatColor(0, 0, 1, 1),
                luminanceLayerColor: RGBAFloatColor = RGBAFloatColor(1, 1, 1, 1)) throws {
        self.gpuHandler = gpuHandler
        self.binsCount = binsCount
        self.layerColors = [redLayerColor, greenLayerColor, blueLayerColor, luminanceLayerColor]
        self.renderTarget = renderTarget
        
        // init render pipeline states
        renderPipelineState = try HistogramRenderer.initRenderPipelineState(device: gpuHandler.device,
                                                                            library: gpuHandler.library)
        super.init()
        
        self.renderTarget.metalView?.delegate = self
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
            
            if let metalView = self.renderTarget.metalView {
                metalView.draw()
            } else {
                self.renderingPass(view: nil)
            }
        }
    }
    
    func renderingPass(view: MTKView?) -> Void {
        guard let histogramBuffer = self.histogramBuffer else { return }
        
        // setup rendering encoder
        guard let commandBuffer = gpuHandler.commandQueue.makeCommandBuffer(), // stores GPU commands
              let renderPassDescription = renderTarget.renderPassDescriptor, // render destinations data
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
                                      length: MemoryLayout<RGBAFloatColor>.stride * layerColors.count,
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
            self.renderTarget.didRender()
        }
        
        // finish commands encoding
        commandEncoder.endEncoding()

        // present view
        if let drawable = view?.currentDrawable {
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
