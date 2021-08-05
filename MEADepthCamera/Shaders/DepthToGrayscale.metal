//
//  DepthToGrayscale.metal
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal compute shader that translates depth values to grayscale RGB values.
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

struct converterParameters {
    float offset;
    float range;
};

// Compute kernel
kernel void depthToGrayscale(texture2d<float, access::read>  inputTexture      [[ texture(TextureIndexDepthInput) ]],
                             texture2d<float, access::write> outputTexture     [[ texture(TextureIndexGrayscaleOutput) ]],
                             constant converterParameters& converterParameters [[ buffer(BufferIndexConverterParameters) ]],
                             uint2 gid [[ thread_position_in_grid ]])
{
    // Don't read or write outside of the texture.
    if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
        return;
    }
    
    float depth = inputTexture.read(gid).x;
    
    // Normalize the value between 0 and 1.
    //depth = (depth - converterParameters.offset) / (converterParameters.range);
    
    float4 outputColor = float4(float3(depth), 1.0);
    
    outputTexture.write(outputColor, gid);
}
