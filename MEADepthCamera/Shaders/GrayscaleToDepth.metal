//
//  GrayscaleToDepth.metal
//  MEADepthCamera
//
//  Created by Will on 8/5/21.
//
/*
Abstract:
Metal compute shader that translates grayscale RGB values to depth values.
*/

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and Swift code executing Metal API commands
#import "ShaderTypes.h"

// Compute kernel
kernel void grayscaleToDepth(texture2d<float, access::read>  inputTexture      [[ texture(TextureIndexInput) ]],
                             texture2d<float, access::write> outputTexture     [[ texture(TextureIndexOutput) ]],
                             constant ConverterParameters& converterParameters [[ buffer(BufferIndexConverterParameters) ]],
                             uint2 gid [[ thread_position_in_grid ]])
{
    // Don't read or write outside of the texture.
    if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
        return;
    }
    
    float4 grayscale = inputTexture.read(gid).x;
    
    // Normalize the value between 0 and 1.
    //depth = (depth - converterParameters.offset) / (converterParameters.range);
    
    // The first three components (red, green, and blue) are all the same so we can choose any of them as our output depth
    float outputDepth = grayscale.r;
    
    outputTexture.write(outputDepth, gid);
}
