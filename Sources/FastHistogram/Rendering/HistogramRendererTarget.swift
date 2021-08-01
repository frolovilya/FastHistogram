import MetalKit

/// Render target to be used for `HistogramRenderer` output.
public protocol HistogramRendererTarget {
    /// Render pass descriptor to render this target.
    var renderPassDescriptor: MTLRenderPassDescriptor? { get }
    
    /// Underlying Metal view, if any.
    var metalView: MTKView? { get }
    
    /// Called when this target is rendered.
    func didRender() -> Void
}

extension HistogramRendererTarget {
    public var metalView: MTKView? {
        return nil
    }
    
    public func didRender() -> Void {
        // do nothing
    }
}
