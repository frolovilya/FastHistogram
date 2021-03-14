#include <metal_stdlib>
#include "../../CShaderHeader/include/Common.h"
using namespace metal;

struct VertexIn {
    float2 position;
};

struct RasterizerData {
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[ position ]];
    
    float4 color [[ flat ]];
};

vertex RasterizerData histogram_bar_vertex(uint vertexId [[ vertex_id ]],
                                           uint instanceId [[ instance_id ]],
                                           constant VertexIn *vertices [[ buffer(HistogramVertexInputIndexVertices) ]],
                                           constant uniform<uint> *histogramBuffer [[ buffer(HistogramVertexInputIndexHistogramBuffer) ]],
                                           constant uniform<uint> &binsCount [[ buffer(HistogramVertexInputIndexBinsCount) ]],
                                           constant uniform<uint> *maxBinValue [[ buffer(HistogramVertexInputIndexMaxBinValue) ]],
                                           constant uniform<float4> *layerColors [[ buffer(HistogramVertexInputIndexColors) ]]) {
    RasterizerData out;
            
    // red - 0
    // green - 1
    // blue - 2
    // alpha - 3
    uint layerIndex = instanceId % 4;
    
    // rgbl data is packed into uint4 in the input histogram buffer
    uint binIndex = instanceId / 4;
    
    // normalized bar height value
    float height = histogramBuffer[instanceId] / float(maxBinValue[layerIndex]);

    // normalized coordinates where [-1, -1] is the bottom left corner
    out.position = float4(0, 0, 0, 1);
    out.position.xy = vertices[vertexId].position;
    
    // set each bar's width so that all instances fill the viewport horizontally
    // [-1..1] / binsCount
    float barWidth = 2.0 / binsCount;
    out.position.x *= barWidth;
    
    // move individual instances along X axis
    out.position.x += barWidth * binIndex;
    
    // adjust each instance's bar height
    out.position.y *= height;
    
    // stretch to fill the whole viewport vertically
    // assuming that heights are normalized and there's always one instance with height 1
    out.position.y *= 2;
    
    // move to the bottom-left corner
    out.position.xy -= 1;
    
    out.color = layerColors[layerIndex];
    
    return out;
}

fragment float4 histogram_bar_fragment(RasterizerData in [[ stage_in ]]) {
    return in.color;
}
