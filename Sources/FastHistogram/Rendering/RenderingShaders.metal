#include <metal_stdlib>
#include "../../CShaderHeader/include/Common.h"
using namespace metal;

constant const uint RGBL_4 = 4;

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

vertex RasterizerData histogramBarVertex(uint vertexId [[ vertex_id ]],
                                         uint instanceId [[ instance_id ]],
                                         constant VertexIn *vertices [[ buffer(HistogramVertexInputIndexVertices) ]],
                                         constant uniform<uint> *histogramBuffer [[ buffer(HistogramVertexInputIndexHistogramBuffer) ]],
                                         constant uniform<uint> &binsCount [[ buffer(HistogramVertexInputIndexBinsCount) ]],
                                         constant uniform<float4> *layerColors [[ buffer(HistogramVertexInputIndexColors) ]]) {
    RasterizerData out;
    
    // red - 0
    // green - 1
    // blue - 2
    // alpha - 3
    uint layerIndex = instanceId % RGBL_4;
    
    // rgbl data is packed into uint4 in the input histogram buffer
    uint binIndex = instanceId / RGBL_4;
    
    // normalized bar height value
    // first 4 bins contains max bin values
    float height = histogramBuffer[instanceId + RGBL_4] / float(histogramBuffer[layerIndex]);

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

fragment float4 histogramBarFragment(RasterizerData in [[ stage_in ]]) {
    return in.color;
}
