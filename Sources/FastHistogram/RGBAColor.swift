import simd
import MetalKit
import Foundation

public struct RGBAColor: Equatable, CustomStringConvertible {
    public let red, green, blue, alpha: UInt8
    
    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public static var red: RGBAColor = RGBAColor(255, 0, 0, 255)
    public static var green: RGBAColor = RGBAColor(0, 255, 0, 255)
    public static var blue: RGBAColor = RGBAColor(0, 0, 255, 255)
    public static var white: RGBAColor = RGBAColor(255, 255, 255, 255)
    public static var black: RGBAColor = RGBAColor(0, 0, 0, 255)
    
    /**
     Get a new RGBA color by changing current color's alpha value
     
     - Parameter alpha: Opacity value [0, 1]
     - Returns: Color with given opacity.
     */
    public func opacity(_ alpha: Double) -> RGBAColor {
        RGBAColor(red, green, blue, UInt8(255 * alpha))
    }
    
    /**
     Blend two colors by adding their RGBA values.
     
     See `MTLBlendOperation.add`,  `MTLBlendFactor.sourceAlpha` and `MTLBlendFactor.oneMinusSourceAlpha`.
     ```
     RGB = Source.rgb * SBF + Dest.rgb * DBF
     A = Source.a * SBF + Dest.a * DBF
     
     SBF = Source.a
     DBF = 1 - Source.a
     ```
     
     - Parameter other: another color to add to the current one.
     - Returns: result of blending two colors.
     */
    func add(_ other: RGBAColor) -> RGBAColor {
        let sbf: Double = Double(alpha) / 255.0
        let dbf: Double = (1 - Double(alpha) / 255.0)
        
        let r = Double(red) * sbf + Double(other.red) * dbf
        let g = Double(green) * sbf + Double(other.green) * dbf
        let b = Double(blue) * sbf + Double(other.blue) * dbf
        let a = Double(alpha) * sbf + Double(other.alpha) * dbf
        
        return RGBAColor(UInt8(round(r)),
                         UInt8(round(g)),
                         UInt8(round(b)),
                         UInt8(round(a)))
    }

    /// Represents RGBA color as a vector of four 32-bit floats.
    var simd: simd_float4 {
        simd_float4(Float(red) / 255.0, Float(green) / 255.0, Float(blue) / 255.0, Float(alpha) / 255.0)
    }
    
    /// Get `MTLClearColor` representation of the RGBA
    var mtlClearColor: MTLClearColor {
        MTLClearColor(red: Double(red) / 255.0,
                      green: Double(green) / 255.0,
                      blue: Double(blue) / 255.0,
                      alpha: Double(alpha) / 255.0)
    }
    
    public var description: String {
        return "(\(red), \(green), \(blue), \(alpha))"
    }
}
