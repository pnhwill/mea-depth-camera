//
//  PassThrough.metal
//  MEADepthCamera
//
//  Created by Will on 7/28/21.
//
/*
Abstract:
 Implements a passthrough shader used for previewing content.
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and Swift code executing Metal API commands
#import "ShaderTypes.h"

// Vertex input/output structure for passing results from vertex shader to fragment shader
struct VertexIO
{
    float4 position [[position]];
    float2 textureCoord [[user(texturecoord)]];
};

// Vertex shader for a textured quad
vertex VertexIO vertexPassThrough(const device packed_float4 *pPosition  [[ buffer(VertexIndexPosition) ]],
                                  const device packed_float2 *pTexCoords [[ buffer(VertexIndexTextureCoordinates) ]],
                                  uint                        vid        [[ vertex_id ]])
{
    VertexIO outVertex;
    
    outVertex.position = pPosition[vid];
    outVertex.textureCoord = pTexCoords[vid];
    
    return outVertex;
}

// Fragment shader for a textured quad
fragment half4 fragmentPassThrough(VertexIO        inputFragment  [[ stage_in ]],
                                   texture2d<half> inputTexture   [[ texture(TextureIndexInput) ]],
                                   sampler         textureSampler [[ sampler(FragmentIndexSampler) ]])
{
    return inputTexture.sample(textureSampler, inputFragment.textureCoord);
}
