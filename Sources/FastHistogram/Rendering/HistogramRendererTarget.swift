import MetalKit

/// Render target to be used for HistogramRenderer output
public protocol HistogramRendererTarget {
    var renderPassDescriptor: MTLRenderPassDescriptor? { get }
    var metalView: MTKView? { get }
}
