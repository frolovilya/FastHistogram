# FastHistogram

GPU-based image RGBL histogram calculation and rendering.


## What's RGBL Histogram?
RGBL histograms shows Red, Green, Blue and Luminocity channels bar chart for an image.
Bar height represents a count of pixels on an image with a corresponding color or luminocity.

Pixel colors inside the sRGB color space are not linear, but with `gamma=2.4` coefficient applied.
_FastHistogram_ supports both linear and gamma-encoded histogram generation and rendering.


## Installation

Use Xcode's built-in Swift Package Manager:

* Open Xcode
* Click File -> Swift Packages -> Add Package Dependency
* Paste package repository https://github.com/frolovilya/FastHistogram.git and press return
* Import module to any file using `import FastHistogram`


## Usage

### Wrapping Into A Simple ViewModel

_FastHistogram_ provides two components for generation and rendering which can be used independently.
Here's how you could wrap everything into a `ViewModel` to generate image's histogram and render it into a SwithUI `View`.

```swift
import FastHistogram

class HistogramViewModel {
    // Specify a count of histogram bins to generate and render
    static let binsCount: Int = 256
    
    private let histogramGenerator: HistogramGenerator
    private let histogramRenderer: HistogramRenderer
    
    var view: some View {
        histogramRenderer.view
    }
    
    init() {
        // Init shared GPU handler
        let gpuHandler = try! GPUHandler()
        
        self.histogramGenerator = try! HistogramGenerator(gpuHandler: gpuHandler,
                                                          binsCount: HistogramViewModel.binsCount)
        
        self.histogramRenderer = try! HistogramRenderer(
            gpuHandler: gpuHandler,
            binsCount: HistogramViewModel.binsCount,
            layerColors: [RGBAColor(1, 0, 0, 0.7),
                          RGBAColor(0, 1, 0, 0.7),
                          RGBAColor(0, 0, 1, 0.7),
                          RGBAColor(1, 1, 1, 0.7)],
            backgroundColor: RGBAColor(0, 0, 0, 1))
            
        let image: PlatformImage = #imageLiteral(resourceName: "IMG_9695")
        guard let cgImage = image.cgImage else { return }
        
        let texture = HistogramTexture(gpuHandler: gpuHandler, cgImage: cgImage)
        
        self.histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            self.histogramRenderer.draw(histogramBuffer: histogramBuffer)
        }
    }
}
```

Now simply show the histogram renderer's view wrapping it into a `UIViewRepresentable` or `NSViewRepresentable`:
```swift
import SwiftUI

@main
struct HistogramApp: App {
    
    let histogramViewModel = HistogramViewModel()
        
    var body: some Scene {
        WindowGroup {
            GeometryReader { g in
                ViewWrapper(view: histogramViewModel.view)
                    .frame(width: g.size.width, height: g.size.height)
            }
        }
    }
}
```

### Continuous High-FPS Rendering
 
Often you need to show not a static image, but high frequency image data coming from device's camera.
Use resource pools for efficient generation and rendering. 
This adds a controlled and synchronized level of paralellism to the CPU <-> GPU work.

When dealing with textures and buffers obtained from a shared resource pool, you're required to explicitly release them back to the pool.
In the simple example above, `histogramGenerator.process` releases the `HistogramTexture` object when finished processing
and `histogramRenderer.draw` releases the `HistogramBuffer` object once it's rendered.

```swift
import Combine
import AVFoundation

// Init shared GPU handler, generator and renderer the same way as it's defined in the previous listing
let gpuHandler: GPUHandler
let histogramGenerator: HistogramGenerator
let histogramRenderer: HistogramRenderer

// Assuming there's some CVImageBuffer publisher defined
let videoFramePublisher: AnyPublisher<CVImageBuffer, Never>

// Texture allocation is a slow process.
// Make a pool of pre-allocated textures to use for high-FPS rendering.
var texturePool: SharedResourcePool<HistogramTexture>?

// Process frames
videoFramePublisher.sink { frame in
    // Obtain frame's height and width in pixels
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    
    // Make sure that texture pool is set up with the same width and height as a receiving frame.
    // In most cases streaming frame size is constant.
    if (texturePool == nil) {
        texturePool = HistogramTexture.makePool(gpuHandler: gpuHandler,
                                                textureSize: MTLSizeMake(width, height, 1),
                                                poolSize: FastHistogramViewModel.texturesPoolSize)
    }
    
    // Get free texture from the pool.
    // This method blocks until a next texture is available.
    let texture = texturePool!.nextResource
    
    texture.fillTextureWithImageBufferData(imageBuffer: frame)
    
    // Process texture, generate RGBL histogram
    histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
        // By this moment, texture is already released by .process method.
        // Render RGBL histogram. After it's done, histogramBuffer is also auto-released.
        histogramRenderer.draw(histogramBuffer: histogramBuffer)
    }
}





