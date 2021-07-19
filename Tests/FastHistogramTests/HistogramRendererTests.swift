import XCTest
import simd
import Combine
@testable import FastHistogram

final class HistogramRendererTests: XCTestCase {
    
    private static let binsCount: Int = 10
    
    var gpuHandler: GPUHandler!
    var histogramGenerator: HistogramGenerator!
    var histogramRenderer: HistogramRenderer!
    var texturePool: SharedResourcePool<HistogramTexture>!
    var outputTexture: HistogramTexture!
    var outputTextureCancellable: AnyCancellable?

    override func setUpWithError() throws {
        gpuHandler = try GPUHandler()
        histogramGenerator = try HistogramGenerator(gpuHandler: gpuHandler,
                                                    binsCount: HistogramRendererTests.binsCount)
        
        outputTexture = HistogramTexture(gpuHandler: gpuHandler,
                                         size: MTLSizeMake(HistogramRendererTests.binsCount, 4, 1),
                                         isRenderTarget: true)
        
        histogramRenderer = try HistogramRenderer(gpuHandler: gpuHandler,
                                                  renderTarget: outputTexture,
                                                  binsCount: HistogramRendererTests.binsCount)
        
        texturePool = HistogramTexture.makePool(gpuHandler: gpuHandler,
                                                textureSize: MTLSizeMake(2, 2, 1),
                                                poolSize: 3)
    }
    
    func testWhite() {
        let pixelData: [UInt8] = [
            255, 255, 255, 255,
            255, 255, 255, 255,
            255, 255, 255, 255,
            255, 255, 255, 255
        ]
        
        let texture = texturePool.nextResource
        texture.fillTextureWithBGRAPixelData(pixelData: pixelData)
        
        outputTextureCancellable = outputTexture.didRenderPublisher.sink { _ in
            self.outputTexture.dumpTextureContents()
        }
        
        histogramGenerator.process(texture: texture, isLinear: false) { histogramBuffer in
            self.histogramRenderer.draw(histogramBuffer: histogramBuffer)
        }
    }

    static var allTests = [
        ("testWhite", testWhite)
    ]
}
