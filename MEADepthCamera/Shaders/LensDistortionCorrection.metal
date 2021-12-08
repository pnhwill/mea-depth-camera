//
//  LensDistortionCorrection.metal
//  MEADepthCamera
//
//  Created by Will on 11/29/21.
//

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and Swift code executing Metal API commands.
#import "ShaderTypes.h"

constexpr sampler textureSampler (coord::pixel, address::clamp_to_edge, filter::nearest);

// Compute kernel for lens distortion correction.
kernel void lensDistortionCorrection(texture2d<float, access::sample> inputTexture [[ texture(TextureIndexInput) ]],
                                     texture2d<float, access::write> outputTexture [[ texture(TextureIndexOutput) ]],
                                     constant float *lookupTableValues             [[ buffer(BufferIndexLookupTableValues) ]],
                                     constant ulong &lookupTableCount              [[ buffer(BufferIndexLookupTableCount) ]],
                                     constant float2 &opticalCenter                [[ buffer(BufferIndexOpticalCenter) ]],
                                     uint2 gid [[thread_position_in_grid]])
{
    
    float2 imageSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 point = float2(gid);
    
    // Check if the pixel is within the bounds of the output texture
    if ((point.x >= imageSize.x) || (point.y >= imageSize.y))
    {
        return;
    }
    
    // lensDistortionPointForPoint()
    
    // The lookup table holds the relative radial magnification for n linearly spaced radii.
    // The first position corresponds to radius = 0
    // The last position corresponds to the largest radius found in the image.
 
    // Determine the maximum radius.
    float delta_ocx_max = max( opticalCenter.x, imageSize.x  - opticalCenter.x );
    float delta_ocy_max = max( opticalCenter.y, imageSize.y - opticalCenter.y );
    float r_max = sqrt( delta_ocx_max * delta_ocx_max + delta_ocy_max * delta_ocy_max );
 
    // Determine the vector from the optical center to the given point.
    float v_point_x = point.x - opticalCenter.x;
    float v_point_y = point.y - opticalCenter.y;
 
    // Determine the radius of the given point.
    float r_point = sqrt( v_point_x * v_point_x + v_point_y * v_point_y );
 
    // Look up the relative radial magnification to apply in the provided lookup table
    float magnification;
    
    if ( r_point < r_max ) {
        // Linear interpolation
        float val   = r_point * ( lookupTableCount - 1 ) / r_max;
        int   idx   = (int)val;
        float frac  = val - idx;
 
        float mag_1 = lookupTableValues[idx];
        float mag_2 = lookupTableValues[idx + 1];
 
        magnification = ( 1.0f - frac ) * mag_1 + frac * mag_2;
    }
    else {
        magnification = lookupTableValues[lookupTableCount - 1];
    }
 
    // Apply radial magnification
    float new_v_point_x = v_point_x + magnification * v_point_x;
    float new_v_point_y = v_point_y + magnification * v_point_y;
    
    float2 correctedPoint = float2( opticalCenter.x + new_v_point_x, opticalCenter.y + new_v_point_y );
    
    // We don't need to manually clamp the point to within the buffer's bounds since the sampler is set to clamp_to_edge.
    float4 pixelValue = inputTexture.sample(textureSampler, correctedPoint);
    
    outputTexture.write(pixelValue, gid);
}
