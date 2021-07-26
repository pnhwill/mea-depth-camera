//
//  ShaderTypes.h
//  MEADepthCamera
//
//  Created by Will on 7/24/21.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

//#include <simd/simd.h>

// Buffer index values shared between the Metal shader and C code ensure the shader buffer
// inputs match the Metal API buffer set calls.
typedef enum VertexInputIndex
{
    VertexInputIndexLandmarks     = 0,
    VertexInputIndexCameraIntrinsics = 1,
    VertexInputIndexPointCloud
} VertexInputIndex;

// Texture index values shared between the Metal shader and C code ensure the shader buffer
// inputs match the Metal API texture set calls.
typedef enum TextureIndex
{
    TextureIndexDepthInput  = 0,
} TextureIndex;


#endif /* ShaderTypes_h */
