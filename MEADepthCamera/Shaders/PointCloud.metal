//
//  PointCloud.metal
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//
/*
Abstract:
Metal compute shader used for point-cloud calculations
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and Swift code executing Metal API commands
#import "ShaderTypes.h"

constexpr sampler textureSampler (coord::pixel, mag_filter::linear, min_filter::linear);

// Compute kernel
kernel void pointCloudKernel(constant float2* landmarks                    [[ buffer(BufferIndexLandmarksInput) ]],
                             texture2d<float, access::sample> depthTexture [[ texture(TextureIndexInput) ]],
                             constant float3x3& cameraIntrinsics           [[ buffer(BufferIndexCameraIntrinsicsInput) ]],
                             device float3* outBuffer                      [[ buffer(BufferIndexPointCloudOutput) ]],
                             uint index [[ thread_position_in_grid ]])
{
    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = landmarks[index].xy;
    
    // Don't sample outside of the texture.
    if ((pixelSpacePosition.x >= depthTexture.get_width()) || (pixelSpacePosition.y >= depthTexture.get_height())) {
        return;
    }
    
    // Depth data pixel format is kCVPixelFormatType_32BGRA
    
    // The first three components (red, green, and blue) are all the same so we can choose any of them as our output depth
    float depth = depthTexture.sample(textureSampler, pixelSpacePosition).r;// * 1000.0f;
    
    // Calculate the absolute physical location of the landmark
    // The depth value units are meters. We can scale all the coordinates just by scaling the depth first
    float x = (pixelSpacePosition.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0];
    float y = (pixelSpacePosition.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1];
    
    // Assign the spatial coordinates to a 3d vector and write to the output buffer
    float3 xyz = float3(x, y, depth);
    outBuffer[index] = xyz;
}
