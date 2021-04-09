import MetalKit
import CShaderHeader

/**
 Wraps image data as Metal texture for histogram generation.
 */
public final class HistogramTexture: PoolResource {
    
    let metalTexture: MTLTexture
    
    public init(gpuHandler: GPUHandler, size: MTLSize) {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        
        metalTexture = gpuHandler.device.makeTexture(descriptor: textureDescriptor)!
    }
    
    public init(gpuHandler: GPUHandler, cgImage: CGImage) {
        metalTexture = try! MTKTextureLoader(device: gpuHandler.device)
            .newTexture(cgImage: cgImage, options: nil)
    }
    
    public static func makePool(gpuHandler: GPUHandler,
                                textureSize: MTLSize,
                                poolSize: Int) -> SharedResourcePool<HistogramTexture> {
        var textures: [HistogramTexture] = []
        for _ in 0..<poolSize {
            textures.append(HistogramTexture(gpuHandler: gpuHandler, size: textureSize))
        }
        return SharedResourcePool(resources: textures)
    }
    
    var size: MTLSize {
        MTLSizeMake(metalTexture.width, metalTexture.height, metalTexture.depth)
    }
    
    public weak var pool: SharedResourcePool<HistogramTexture>?

    public func release() -> Void {
        pool?.release(resource: self)
    }
    
    public func fillTexture(data: UnsafeRawPointer,
                            bytesPerRow: Int? = nil) -> Void {
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0),
                               size: size)
                
        metalTexture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: data,
                        bytesPerRow: bytesPerRow ?? (RGBL_4 * metalTexture.width))
    }
    
    public func fillTextureWithBGRAPixelData(pixelData: [UInt8]) -> Void {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: RGBL_4 * metalTexture.width * metalTexture.height)
        pointer.initialize(from: pixelData, count: pixelData.count)
        fillTexture(data: pointer)
    }
    
    public func fillTextureWithImageBufferData(imageBuffer: CVImageBuffer) throws -> Void {
        // Lock the image buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            // Unlock the image buffer on method exit
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }
        
        guard CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_32BGRA else {
            print("Only BGRA pixel format supported")
            throw GPUOperationError.textureFormatError
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else {
            print("Unable to get CVImageBuffer's base address")
            throw GPUOperationError.textureFormatError
        }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard metalTexture.width == width && metalTexture.height == height else {
            print("Texture's size in pixels doesn't match image buffer size")
            throw GPUOperationError.textureFormatError
        }
                
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        fillTexture(data: buffer,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer))
    }
    
}
