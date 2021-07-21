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
    
    public func opacity(_ value: Double) -> RGBAColor {
        RGBAColor(red, green, blue, UInt8(Double(alpha) * value))
    }

    /// Represents RGBA color as a vector of four 32-bit floats.
    var simd: simd_float4 {
        simd_float4(Float(red) / 255.0, Float(green) / 255.0, Float(blue) / 255.0, Float(alpha) / 255.0)
    }
    
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
