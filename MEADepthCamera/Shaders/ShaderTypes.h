//
//  ShaderTypes.h
//  MEADepthCamera
//
//  Created by Will on 7/24/21.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

// Buffer index values shared between the Metal shader and C code ensure the shader buffer
// inputs match the Metal API buffer set calls.
typedef enum BufferIndex
{
    BufferIndexConverterParameters   = 0,
    BufferIndexLandmarksInput        = 1,
    BufferIndexCameraIntrinsicsInput = 2,
    BufferIndexPointCloudOutput      = 3,
} BufferIndex;

// Texture index values shared between the Metal shader and C code ensure the shader buffer
// inputs match the Metal API texture set calls.
typedef enum TextureIndex
{
    TextureIndexDepthInput      = 0,
    TextureIndexGrayscaleOutput = 1,
} TextureIndex;


#endif /* ShaderTypes_h */
