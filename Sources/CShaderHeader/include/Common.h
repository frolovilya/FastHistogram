#ifndef Common_h
#define Common_h

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
    HistogramGeneratorInputIndexHistogramBuffer
};

enum HistogramVertexInputIndex {
    HistogramVertexInputIndexVertices,
    HistogramVertexInputIndexHistogramBuffer,
    HistogramVertexInputIndexBinsCount,
    HistogramVertexInputIndexColors,
    HistogramVertexInputIndexEnabledLayers
};

#endif /* Common_h */
