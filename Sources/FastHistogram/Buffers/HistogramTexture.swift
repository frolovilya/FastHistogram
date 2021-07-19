import MetalKit
import CShaderHeader
import Combine

/**
 Wraps image data as Metal texture to use as an input for histogram generation.
 */
public final class HistogramTexture: PoolResource, HistogramRendererTarget {
    
    let metalTexture: MTLTexture
    
    /**
     Init new texture instance with given `size`.
     
     Use texture pool by calling `makePool` static method, if you need to allocate multiple textures for high-FPS rendering.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter size: texture size to generate.
     - Parameter isRenderTarget: whether to use the texture as a render target for the HistogramRenderer.
     */
    public init(gpuHandler: GPUHandler, size: MTLSize, isRenderTarget: Bool = false) {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        if isRenderTarget {
            textureDescriptor.usage = .renderTarget
        }
        
        metalTexture = gpuHandler.device.makeTexture(descriptor: textureDescriptor)!
    }
    
    /**
     Init new texture instance for a given `CGImage`.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter cgImage: `CGImage` to generate texture from.
     */
    public init(gpuHandler: GPUHandler, cgImage: CGImage) {
        metalTexture = try! MTKTextureLoader(device: gpuHandler.device)
            .newTexture(cgImage: cgImage, options: nil)
    }
    
    /**
     Make a pool of shared texture objects to re-use between frames for histogram generation.
     
     - Parameter gpuHandler: `GPUHandler` instance.
     - Parameter textureSize: All textures in the pool are of a fixed size. If input data size changes, new pool must be created.
     - Parameter poolSize: number of shared texture objects in the pool.
     */
    public static func makePool(gpuHandler: GPUHandler,
                                textureSize: MTLSize,
                                poolSize: Int = 3) -> SharedResourcePool<HistogramTexture> {
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

    /// Release this texture instance back to the shared pool
    public func release() -> Void {
        pool?.release(resource: self)
    }
    
    /// Render pass descriptor to use this texture as a render target
    public var renderPassDescriptor: MTLRenderPassDescriptor? {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = metalTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
    
    private lazy var didRenderSubject = PassthroughSubject<Void, Never>()
    /// Publishes value any time this texture is rendered
    public var didRenderPublisher: AnyPublisher<Void, Never> {
        didRenderSubject.eraseToAnyPublisher()
    }
    public func didRender() {
        didRenderSubject.send()
    }
    
    /**
     Copy raw data into texture.
     
     - Parameter data: A pointer to the bytes in memory to copy.
     - Parameter bytesPerRow: The stride, in bytes, between rows of source data. Optional, by default equals to texture width in pixels multiplied by 4.
     */
    public func fillTexture(data: UnsafeRawPointer,
                            bytesPerRow: Int? = nil) -> Void {
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0),
                               size: size)
                
        metalTexture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: data,
                        bytesPerRow: bytesPerRow ?? (RGBA_4 * metalTexture.width))
    }
    
    /**
     Fill texture with BGRA pixel data by copying it from a given array of 8-bit pixel colors.
     
     - Precondition: Colors in the array must be ordered in the BGRA format. Size of the array must be equal to texture `width * height * 4`.
     
     - Parameter pixelData: array of pixel colors to fill texture with.
     */
    public func fillTextureWithBGRAPixelData(pixelData: [UInt8]) -> Void {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: RGBA_4 * metalTexture.width * metalTexture.height)
        pointer.initialize(from: pixelData, count: pixelData.count)
        fillTexture(data: pointer)
    }
    
    /**
     Fill texture by copying `CVImageBuffer` data.
     
     - Precondition: Buffer has to be in the 32BGRA format. Buffer's width and height must correspond to the texture size.
     
     - Parameter imageBuffer `CVImageBuffer` to copy data from.
     */
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
    
    /**
     Allocates memory and copies texture contents into it.
     
     Do not forget to `.deallocate()` when finished working with the data.
     
     - Returns: Pointer to the first (0, 0) pixels blue color
     */
    func getData() -> UnsafeMutablePointer<UInt8> {
        let width = metalTexture.width
        let height = metalTexture.height
        let bytesPerRow = width * RGBA_4 // RGBA, each 8 bits, 4 bytes in total

        let data = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * height,
                                                    alignment: RGBA_4)

        let region = MTLRegionMake2D(0, 0, width, height)
        metalTexture.getBytes(data,
                              bytesPerRow: bytesPerRow,
                              from: region,
                              mipmapLevel: 0)
        
        return data.assumingMemoryBound(to: UInt8.self)
    }
    
    /**
     Get pixel RGBA color at the specified (x, y) location.
     
     - Parameter x: pixel's coordinate on the horizontal axis
     - Parameter y: pixel's coordinate on the vertical axis
     
     - Returns: RGBA color as a vector of four 8-bit integers.
     */
    public func getPixelColor(x: Int, y: Int) -> RGBAIntColor {
        let data = getData()
        defer {
            data.deallocate()
        }
        
        let pointer = data.advanced(by: (x + y * metalTexture.width) * RGBA_4)
        
        // texture has .bgra8Unorm format
        let blue = pointer.pointee
        let green = pointer.advanced(by: 1).pointee
        let red = pointer.advanced(by: 2).pointee
        let alpha = pointer.advanced(by: 3).pointee
        
        return (red, green, blue, alpha)
    }
    
    public func dumpTextureContents() -> Void {
        for h in 0..<metalTexture.height {
            for w in 0..<metalTexture.width {
                print((w, h), getPixelColor(x: w, y: h))
            }
        }
    }
    
}
