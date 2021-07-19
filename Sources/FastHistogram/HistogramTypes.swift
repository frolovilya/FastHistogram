import simd

/// Convenience `4` multiplier.
let RGBL_4: Int = 4
let RGBA_4: Int = 4

/// Represents RGBA color as a vector of four 32-bit floats.
public typealias RGBAFloatColor = simd_float4

/// Represents RGBA color as a vector of four 8-bit integers.
public typealias RGBAIntColor = (UInt8, UInt8, UInt8, UInt8)

/// Represents RGBL histrogram bin as a vector of four 32-bit unsigned integers.
public typealias RGBLBin = simd_uint4

/// Represents single R or G or B or L bin cell as 32-bit unsigned integer.
public typealias RGBLBinCell = simd_uint1
