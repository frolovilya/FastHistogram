import MetalKit
import Combine

/**
 `MTKView` histogram view wrapper.
 */
public class HistogramView: HistogramRendererTarget {

    /// Underlying Metal View
    public let metalView: MTKView?
    
    /**
     Initiate new histogram view instance. Use this view for HistogramRenderer output.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter backgroundColor: view's background RGBA color.
     */
    public init(gpuHandler: GPUHandler,
                backgroundColor: RGBAColor) {
        metalView = MTKView(frame: CGRect(x: 0, y: 0, width: 1, height: 1),
                            device: gpuHandler.device)
        
        metalView!.isPaused = true
        metalView!.enableSetNeedsDisplay = false

        #if os(iOS)
        metalView!.isOpaque = false
        #endif
        metalView!.clearColor = MTLClearColor(red: Double(backgroundColor[0]),
                                              green: Double(backgroundColor[1]),
                                              blue: Double(backgroundColor[2]),
                                              alpha: Double(backgroundColor[3]))
    }
    
    #if os(OSX)
    /// Underlying UI view
    public var view: some NSView {
        metalView!
    }
    #else
    /// Underlying UI view
    public var view: some UIView {
        metalView!
    }
    #endif
    
    /// View's render pass descriptor
    public var renderPassDescriptor: MTLRenderPassDescriptor? {
        metalView!.currentRenderPassDescriptor
    }

}
