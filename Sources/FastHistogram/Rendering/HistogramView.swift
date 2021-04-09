import MetalKit

/**
 `MTKView` histogram view wrapper.
 */
class HistogramView {
    
    let view: MTKView
    
    init(device: MTLDevice,
         delegate: MTKViewDelegate,
         backgroundColor: RGBAColor) {
        
        view = MTKView(frame: CGRect(x: 0, y: 0, width: 256, height: 100),
                       device: device)
        view.delegate = delegate
        
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        
        #if os(iOS)
        view.isOpaque = false
        #endif
        view.clearColor = MTLClearColor(red: Double(backgroundColor[0]),
                                        green: Double(backgroundColor[1]),
                                        blue: Double(backgroundColor[2]),
                                        alpha: Double(backgroundColor[3]))

    }
}
