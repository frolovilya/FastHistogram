import MetalKit

public enum GPUOperationError: Error {
    case initializationError
}

public class GPUHandler {
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary
    
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
    
}
