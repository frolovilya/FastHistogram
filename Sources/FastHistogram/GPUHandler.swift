import MetalKit

/**
 Wraps GPU device and required resources to be shared between histogram generation and rendering classes.
 */
public class GPUHandler {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    /**
     Init new `GPUHandler` instance.
     
     - Throws `initializationError` if unable to initialize all required GPU resources.
     */
    public init() throws {
        // init GPU device
        guard let device = MTLCreateSystemDefaultDevice()
        else { throw GPUOperationError.initializationError }
        self.device = device
        
        // init command queue
        guard let commandQueue = device.makeCommandQueue()
        else { throw GPUOperationError.initializationError }
        self.commandQueue = commandQueue
        
        // setup Metal library with shader functions
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
        else { throw GPUOperationError.initializationError }
        self.library = library
    }
    
    /// The capture manager captures commands only within MTLCommandBuffer objects
    /// that are created after the capture starts and are committed before the capture stops.
    func startProgrammaticCapture() {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = device
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
    }
    
    func stopProgrammaticCapture() {
        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
    }
    
    var supportsNonUniformThreadgroupSize: Bool {
        return device.supportsFamily(.common3)
            || device.supportsFamily(.apple4)
            || device.supportsFamily(.apple5)
            || device.supportsFamily(.apple6)
            || device.supportsFamily(.apple7)
            || device.supportsFamily(.mac1)
            || device.supportsFamily(.mac2)
            || device.supportsFamily(.macCatalyst1)
            || device.supportsFamily(.macCatalyst2)
    }
    
}
