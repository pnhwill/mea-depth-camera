//
//  PointCloud.metal
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for point-cloud calculations
*/

#include <metal_stdlib>
using namespace metal;

// Vertex Function
vertex void vertexShaderPoints(uint vertexID [[ vertex_id ]],
                               constant float2* landmarks [[ buffer(0) ]],
                               texture2d<float, access::sample> depthTexture [[ texture(0) ]],
                               constant float3x3& cameraIntrinsics [[ buffer(1) ]],
                               device float3* outBuffer [[ buffer(2) ]])
{
    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = landmarks[vertexID].xy;
    
    //float2 textureCoords = pixelSpacePosition / (viewportSize / 2.0);
    //float2 textureCoords = { pos.x / (depthTexture.get_width() - 1.0f), pos.y / (depthTexture.get_height() - 1.0f) };
    
    //uint2 pos;
    //pos.y = vertexID / depthTexture.get_width();
    //pos.x = vertexID % depthTexture.get_width();
    //float depth = depthTexture.read(pos).x * 1000.0f;
    
    // depthDataType is kCVPixelFormatType_DepthFloat16
    constexpr sampler textureSampler (coord::pixel, mag_filter::linear, min_filter::linear);
    float depth = depthTexture.sample(textureSampler, pixelSpacePosition).x * 1000.0f;
    
    // Calculate the absolute physical location of the landmark
    float xrw = (pixelSpacePosition.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0];
    float yrw = (pixelSpacePosition.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1];
    
    float3 xyz = { xrw, yrw, depth };
    
    outBuffer[vertexID] = xyz;
}
