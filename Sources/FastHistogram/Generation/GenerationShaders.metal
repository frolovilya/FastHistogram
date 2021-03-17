#include <metal_stdlib>
#include "../../CShaderHeader/include/Common.h"
using namespace metal;

constant const uint RGBL_4 = 4;
constant const float GAMMA = 2.4;
constant const float RED_PERCEPTION = 0.2126;
constant const float GREEN_PERCEPTION = 0.7152;
constant const float BLUE_PERCEPTION = 0.0722;

/**
 Linearize sRGB gamma encoded color value
 https://en.wikipedia.org/wiki/SRGB#The_reverse_transformation
 */
float sRGBLinearized(float colorChannel) {
    if (colorChannel <= 0.04045) {
        return colorChannel / 12.92;
    } else {
        return pow(((colorChannel + 0.055) / 1.055), GAMMA);
    }
}

/**
 Map normalized [0..1] value to bin index [0..binsCount)
 */
unsigned int normalizedValueToBinIndex(float value, unsigned int binsCount) {
    return round(value * (binsCount - 1));
}

/**
 Calculate luminocity for a given RGB value.
 https://en.wikipedia.org/wiki/Relative_luminance
 */
float sRGBToRelativeLuminance(simd_float3 rgb) {
    return (RED_PERCEPTION * rgb[Red] + GREEN_PERCEPTION * rgb[Green] + BLUE_PERCEPTION * rgb[Blue]);
}

/**
 Increment bin value and update max value for that bin
 */
void addToBin(volatile device atomic_uint *bin,
              volatile device atomic_uint *maxBinValue) {
    uint previousBinValue = atomic_fetch_add_explicit(bin, 1, memory_order_relaxed);
    atomic_fetch_max_explicit(maxBinValue, previousBinValue + 1, memory_order_relaxed);
}

kernel void zeroHistogramBuffer(uint index [[ thread_position_in_grid ]],
                                 volatile device uint *histogram [[ buffer(HistogramGeneratorInputIndexHistogramBuffer) ]]) {
    histogram[index] = 0;
}

kernel void zeroMaxBinValueBuffer(uint index [[ thread_position_in_grid ]],
                            volatile device uint *maxBinValue [[ buffer(HistogramGeneratorInputIndexMaxBinValueBuffer) ]]) {
    maxBinValue[index] = 0;
}

kernel void generateHistogram(texture2d<float, access::read> frame [[ texture(HistogramGeneratorInputIndexTexture) ]],
                              constant uniform<uint> &binsCount [[ buffer(HistogramGeneratorInputIndexBinsCount) ]],
                              constant uniform<bool> &isLinear [[ buffer(HistogramGeneratorInputIndexIsLinear) ]],
                              uint2 index [[ thread_position_in_grid ]],
                              volatile device atomic_uint *output [[ buffer(HistogramGeneratorInputIndexHistogramBuffer) ]],
                              volatile device atomic_uint *maxBinValue [[ buffer(HistogramGeneratorInputIndexMaxBinValueBuffer) ]]) {
    
    // read gamma encoded normalized color RGBA values
    float4 rgba = frame.read(index);
    
    // get just RGB part
    float3 rgb;
    if (isLinear) {
        rgb = float3(sRGBLinearized(rgba[Red]), sRGBLinearized(rgba[Green]), sRGBLinearized(rgba[Blue]));
    } else {
        // gamma encoded
        rgb = float3(rgba[Red], rgba[Green], rgba[Blue]);
    }
    
    // calculate relative luminance
    float luminance = sRGBToRelativeLuminance(rgb);
    
    uint4 rgblBins = uint4(normalizedValueToBinIndex(rgb[Red], binsCount),
                           normalizedValueToBinIndex(rgb[Green], binsCount),
                           normalizedValueToBinIndex(rgb[Blue], binsCount),
                           normalizedValueToBinIndex(luminance, binsCount));
        
    addToBin(&output[rgblBins[Red] * RGBL_4], &maxBinValue[Red]);
    addToBin(&output[rgblBins[Green] * RGBL_4 + Green], &maxBinValue[Green]);
    addToBin(&output[rgblBins[Blue] * RGBL_4 + Blue], &maxBinValue[Blue]);
    addToBin(&output[rgblBins[Luminance] * RGBL_4 + Luminance], &maxBinValue[Luminance]);
}
