import MetalKit

public class TextureFactory {
    
    private let device: MTLDevice
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    public func createTexture(size: MTLSize) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    public func createTextureForImage(cgImage: CGImage) -> MTLTexture? {
        return try? MTKTextureLoader(device: device)
            .newTexture(cgImage: cgImage, options: nil)
    }
    
    public func fillTexture(texture: MTLTexture,
                            data: UnsafeRawPointer,
                            bytesPerRow: Int? = nil) -> Void {
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0),
                               size: MTLSizeMake(texture.width, texture.height, 1))
                
        texture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: data,
                        bytesPerRow: bytesPerRow ?? (RGBL_4 * texture.width))
    }
    
    public func fillTextureWithBGRAPixelData(texture: MTLTexture, pixelData: [UInt8]) -> Void {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: RGBL_4 * texture.width * texture.height)
        pointer.initialize(from: pixelData, count: pixelData.count)
        
        fillTexture(texture: texture, data: pointer)
    }
    
    public func fillTextureWithImageBufferData(texture: MTLTexture, imageBuffer: CVImageBuffer) -> Void {
        // Lock the image buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            // Unlock the image buffer on method exit
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }
        
        guard CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_32BGRA else {
            print("Only BGRA pixel format supported")
            return
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else {
            print("Unable to get CVImageBuffer's base address")
            return
        }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard texture.width == width && texture.height == height else {
            print("Texture's size in pixels doesn't match image buffer size")
            return
        }
                
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        fillTexture(texture: texture,
                    data: buffer,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer))
    }
    
}
