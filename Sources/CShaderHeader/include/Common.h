#ifndef Common_h
#define Common_h

#import <simd/simd.h>

enum HistogramLayer {
    Red = 0,
    Green = 1,
    Blue = 2,
    Luminance = 3
};

enum HistogramGeneratorInputIndex {
    HistogramGeneratorInputIndexTexture,
    HistogramGeneratorInputIndexBinsCount,
    HistogramGeneratorInputIndexIsLinear,
    HistogramGeneratorInputIndexResultBuffer,
    HistogramGeneratorInputIndexMaxBinValue
};

enum HistogramVertexInputIndex {
    HistogramVertexInputIndexVertices,
    HistogramVertexInputIndexHistogramBuffer,
    HistogramVertexInputIndexBinsCount,
    HistogramVertexInputIndexMaxBinValue,
    HistogramVertexInputIndexColors
};

#endif /* Common_h */
