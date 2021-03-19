import MetalKit

class TextureFactory {
    
    static func createTexture(device: MTLDevice, size: MTLSize) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    static func textureForImage(device: MTLDevice, cgImage: CGImage) -> MTLTexture? {
        return try? MTKTextureLoader(device: device)
            .newTexture(cgImage: cgImage, options: nil)
    }
    
    static func fillTexture(texture: MTLTexture, data: UnsafeRawPointer) -> Void {
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0),
                               size: MTLSizeMake(texture.width, texture.height, 1))
                
        texture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: data,
                        bytesPerRow: RGBL_4 * texture.width)
    }
    
    static func fillTextureWithPixelData(texture: MTLTexture, pixelData: [UInt8]) -> Void {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: RGBL_4 * texture.width * texture.height)
        pointer.initialize(from: pixelData, count: pixelData.count)
        
        fillTexture(texture: texture, data: pointer)
    }
    
}
