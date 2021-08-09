//
//  DepthToGrayscale.metal
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
Abstract:
Metal compute shader that translates depth values to grayscale RGB values.
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and Swift code executing Metal API commands
#import "ShaderTypes.h"

// Compute kernel
kernel void depthToGrayscale(texture2d<float, access::read>  inputTexture  [[ texture(TextureIndexInput) ]],
                             texture2d<float, access::write> outputTexture [[ texture(TextureIndexOutput) ]],
                             uint2 gid [[ thread_position_in_grid ]])
{
    // Don't read or write outside of the texture.
    if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
        return;
    }
    
    float depth = inputTexture.read(gid).x;
    
    // Without normalization, the pixel conversion to the texture clamps the values between 0 and 1 and then scales to [0,255] when it is written
    // i.e. all depth data beyond 1 meter is discarded during this operation
    
    float4 outputColor = float4(float3(depth), 1.0);
    
    outputTexture.write(outputColor, gid);
}
