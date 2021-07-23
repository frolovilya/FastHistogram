# FastHistogram

GPU-based image RGBL histogram calculation and rendering. Uses Metal to calculate and draw high-FPS histograms.

* [What's RGBL Histogram](#whatsHistogram)
* [Installation](#installation)
* [Usage](#usage)
  * [Wrapping Into a ViewModel](#wrapIntoViewModel)
  * [Continuous High-FPS Rendering](#highFPS)
  
<a name="whatsHistogram"/>

## What's RGBL Histogram?
RGBL histogram shows Red, Green, Blue and Luminocity channels bar chart for an image.
Bar height represents a count of pixels on an image with a corresponding color or luminocity.

Pixel colors inside the sRGB color space are not linear, but with `gamma=2.4` coefficient applied.
_FastHistogram_ supports both linear and gamma-encoded histogram generation and rendering.
    
![Histogram](https://user-images.githubusercontent.com/271293/125408301-73735c00-e3c3-11eb-88ed-bf7f97f15941.png)

<a name="installation"/>

## Installation

Use Xcode's built-in Swift Package Manager:

* Open Xcode
* Click File -> Swift Packages -> Add Package Dependency
* Paste package repository https://github.com/frolovilya/FastHistogram.git and press return
* Import module to any file using `import FastHistogram`

<a name="usage"/>

## Usage

_FastHistogram_ provides two components for generation and rendering which can be used independently.
`HistogramGenerator` uses `HistogramTexture` filled with pixel data from an image and outputs `HistogramBuffer` with RGBL data.
`HistogramRenderer` takes `HistogramBuffer` as an argument and draws RGBL bins.
Both generation and rendering phases are performed on the GPU.

<a name="wrapIntoViewModel"/>

### Wrapping Into a ViewModel

Here's how you could wrap everything into a `ViewModel` to generate image's histogram and render it into a SwithUI `View`.

```swift
import FastHistogram

class HistogramViewModel {
    // Specify a count of histogram bins to generate and render
    static let binsCount: Int = 256
    
    private let gpuHandler: GPUHandler
    private let histogramGenerator: HistogramGenerator
    private let histogramRenderer: HistogramRenderer
    private let histogramView: HistogramView
    
    var view: some View {
        histogramView.view
    }
    
    init() {
        // Init shared GPU handler
        gpuHandler = try! GPUHandler()
        
        // Init HistogramGenerator
        histogramGenerator = try! HistogramGenerator(gpuHandler: gpuHandler,
                                                     binsCount: HistogramViewModel.binsCount)
                                                     
        histogramView = HistogramView(gpuHandler: gpuHandler,
                                      backgroundColor: RGBAColor.black)
        
        // Init HistogramRenderer
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
        
        let texture = HistogramTexture(gpuHandler: gpuHandler, cgImage: cgImage)
        
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
                ViewWrapper(view: histogramViewModel.view)
                    .frame(width: g.size.width, height: g.size.height)
                    .onAppear {
                        histogramViewModel.generateAndRender()
                    }
            }
        }
    }
}
```

<a name="highFPS"/>

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

class HistogramViewModel {

    // Assuming there's some CVImageBuffer publisher defined
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
            // In most cases streaming frame size is constant.
            if (texturePool == nil) {
                texturePool = HistogramTexture.makePool(gpuHandler: gpuHandler,
                                                        textureSize: MTLSizeMake(width, height, 1))
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
    }
}

```
