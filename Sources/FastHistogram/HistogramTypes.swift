import simd

/// Convenience `4` multiplier.
let RGBL_4: Int = 4

/// Represents RGBA color as a vector of four 32-bit floats.
public typealias RGBAColor = simd_float4

/// Represents RGBL histrogram bin as a vector of four 32-bit unsigned integers.
public typealias RGBLBin = simd_uint4

/// Represents single R or G or B or L bin cell as 32-bit unsigned integer.
public typealias RGBLBinCell = simd_uint1
