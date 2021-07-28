//
//  PointCloud.metal
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal compute shader used for point-cloud calculations
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

// Compute kernel
kernel void pointCloudKernel(constant float2* landmarks                    [[ buffer(BufferIndexLandmarksInput) ]],
                             texture2d<float, access::sample> depthTexture [[ texture(TextureIndexDepthInput) ]],
                             constant float3x3& cameraIntrinsics           [[ buffer(BufferIndexCameraIntrinsicsInput) ]],
                             device float3* outBuffer                      [[ buffer(BufferIndexPointCloudOutput) ]],
                             uint index [[ thread_position_in_grid ]])
{
    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = landmarks[index].xy;
    
    // depthDataType is kCVPixelFormatType_DepthFloat32
    constexpr sampler textureSampler (coord::pixel, mag_filter::linear, min_filter::linear);
    
    // The depth value units are meters. We can scale all the coordinates by simply scaling the depth here
    float depth = depthTexture.sample(textureSampler, pixelSpacePosition).x;// * 1000.0f;
    
    // Calculate the absolute physical location of the landmark
    float xrw = (pixelSpacePosition.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0];
    float yrw = (pixelSpacePosition.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1];
    
    // Assign the spatial coordinates to a 3d vector and write to the output buffer
    float3 xyz = float3(xrw, yrw, depth);
    outBuffer[index] = xyz;
}
