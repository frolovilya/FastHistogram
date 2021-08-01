# FastHistogram

_GPU-based image RGBL histogram calculation and rendering._

* [About](#about)
* [Installation](#installation)
* [Usage](#usage)
  * [Getting Started](#gettingStarted)
  * [Continuous High-FPS Rendering](#highFPS)
  
<a name="about"/>

## About

_FastHistogram_ uses Metal framework to calculate and draw high-FPS histograms.
It provides two components for generation and rendering which can be used independently.

RGBL histogram shows Red, Green, Blue and Luminocity channels bar chart for an image.
Bar height represents a count of pixels with a corresponding color or luminocity.
    
![Histogram](https://user-images.githubusercontent.com/271293/125408301-73735c00-e3c3-11eb-88ed-bf7f97f15941.png)

Pixel colors inside the sRGB color space are not linear, but with `gamma=2.4` coefficient applied.
_FastHistogram_ supports both linear and gamma-encoded histogram generation and rendering.

<a name="installation"/>

## Installation

Use Xcode's built-in Swift Package Manager:

* Open Xcode
* Click File -> Swift Packages -> Add Package Dependency
* Paste package repository https://github.com/frolovilya/FastHistogram.git and press return
* Import module to any file using `import FastHistogram`

<a name="usage"/>

## Usage

There are two main classes to work with histograms:
* `HistogramGenerator` uses `HistogramTexture` filled with pixel data and outputs `HistogramBuffer` with RGBL data.
* `HistogramRenderer` takes `HistogramBuffer` as an argument and draws RGBL bins either on-screen or to another `HistogramTexture`.
Both generation and rendering phases are performed on the GPU.

<a name="gettingStarted"/>

### Getting Started

Here's how you could wrap everything into a `ViewModel` to generate image's histogram and render it into a SwithUI `View`.

```swift
import FastHistogram

class HistogramViewModel {
    // Specify a count of histogram bins to generate and render
    static let binsCount: Int = 256
    
    private let gpuHandler: GPUHandler
    private let histogramGenerator: HistogramGenerator
    private let histogramRenderer: HistogramRenderer
    
    let histogramView: HistogramView
    
    init() {
        // Init shared GPU handler
        gpuHandler = try! GPUHandler()
        
        // Init HistogramGenerator
        histogramGenerator = try! HistogramGenerator(gpuHandler: gpuHandler,
                                                     binsCount: HistogramViewModel.binsCount)
        
        // Init rendering target, in this example it's a View
        histogramView = HistogramView(gpuHandler: gpuHandler,
                                      backgroundColor: RGBAColor.black)
        
        // Init HistogramRenderer, optionally specify layer colors
        histogramRenderer = try! HistogramRenderer(
            gpuHandler: gpuHandler,
            renderTarget: histogramView,
            redLayerColor: RGBAColor.red.opacity(0.7),
            greenLayerColor: RGBAColor.green.opacity(0.7),
            blueLayerColor: RGBAColor.blue.opacity(0.7),
            luminanceLayerColor: RGBAColor.white.opacity(0.7))
    }
    
    func generateAndRender() {
        // Get some image to generate histogram for
        let image: UIImage = #imageLiteral(resourceName: "SomeImage")
        guard let cgImage = image.cgImage else { return }
        
        // Init texture by passing `CGImage` data. 
        // There're many other ways you can init or fill texture, see the class doc comments.
        let texture = HistogramTexture(gpuHandler: gpuHandler, cgImage: cgImage)
        
        // Calculate histogram and draw it
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            self.histogramRenderer.draw(histogramBuffer: histogramBuffer)
        }
    }
}
```

Now simply show the histogram renderer's view wrapping it into a SwiftUI's `UIViewRepresentable` or `NSViewRepresentable`:
```swift
import SwiftUI

@main
struct HistogramApp: App {
    
    let histogramViewModel = HistogramViewModel()
        
    var body: some Scene {
        WindowGroup {
            GeometryReader { g in
                // Either `UIViewRepresentable` or `NSViewRepresentable`
                ViewWrapper(view: histogramViewModel.histogramView.view)
                    .frame(width: g.size.width, height: g.size.height)
                    .onAppear {
                        // Draw the histogram when the view has been placed and resized
                        histogramViewModel.generateAndRender()
                    }
            }
        }
    }
}
```

<a name="highFPS"/>

### Continuous High-FPS Rendering
 
It's often needed to show not a static image's histogram, but generate histograms for a high frequency image data coming from device's camera.

For more efficiency, do not directly initiate `HistogramTexture` and `HistogramBuffer` objects, but use resource pools. 
This adds a controlled and synchronized level of paralellism to the CPU <-> GPU work.

When dealing with textures and buffers obtained from a shared resource pool, you're required to explicitly release them back to the pool.
In the simple example above, `histogramGenerator.process` releases the `HistogramTexture` object when finished processing
and `histogramRenderer.draw` releases the `HistogramBuffer` object once it's rendered.

```swift
import Combine
import AVFoundation

class HistogramViewModel {

    // Assuming there's some CVImageBuffer publisher defined which published image data with high frequency
    let videoFramePublisher: AnyPublisher<CVImageBuffer, Never>
    var videoFramePublisherCancellable: AnyCancellable?

    // Texture allocation is a slow process.
    // Make a pool of pre-allocated textures to use for high-FPS rendering.
    var texturePool: SharedResourcePool<HistogramTexture>?

    init() {
        // Init shared GPU handler, generator and renderer the same way as it's defined in the previous listing
        // ...

        // Process frames
        videoFramePublisherCancellable = videoFramePublisher.sink { frame in
            // Obtain frame's height and width in pixels
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            
            // Make sure that texture pool is set up with the same width and height as a receiving frame.
            // In most cases streaming frame size is constant, so the pool is going to be init only once.
            if (self.texturePool == nil) {
                self.texturePool = HistogramTexture.makePool(gpuHandler: gpuHandler,
                                                             textureSize: MTLSizeMake(width, height, 1))
            }
            
            // Get free texture from the pool.
            // This method blocks until a next texture is available.
            let texture = self.texturePool!.nextResource
            
            texture.fillTextureWithImageBufferData(imageBuffer: frame)
            
            // Process texture, generate RGBL histogram
            self.histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
                // By this moment, `texture` is already released by `.process` method.
                // Render RGBL histogram. After it's done, `histogramBuffer` is also auto-released.
                self.histogramRenderer.draw(histogramBuffer: histogramBuffer)
            }
        }
    }
}

```
