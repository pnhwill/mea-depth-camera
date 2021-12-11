//
//  ShaderTypes.h
//  MEADepthCamera
//
//  Created by Will on 7/24/21.
//
/*
Abstract:
Header containing types and enum constants shared between Metal shaders and Swift sources
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

//#include <simd/simd.h>

// Buffer index values shared between the Metal shader and Swift code ensure the shader buffer
// inputs match the Metal API buffer set calls.
typedef enum BufferIndex {
    BufferIndexLandmarksInput        = 0,
    BufferIndexCameraIntrinsicsInput = 1,
    BufferIndexPointCloudOutput      = 2,
    BufferIndexLookupTableValues     = 3,
    BufferIndexLookupTableCount      = 4,
    BufferIndexOpticalCenter         = 5,
} BufferIndex;

// Texture index values shared between the Metal shader and Swift code ensure the shader buffer
// inputs match the Metal API texture set calls.
typedef enum TextureIndex {
    TextureIndexInput  = 0,
    TextureIndexOutput = 1,
} TextureIndex;

typedef enum VertexIndex {
    VertexIndexPosition           = 0,
    VertexIndexTextureCoordinates = 1,
} VertexIndex;

typedef enum FragmentIndex {
    FragmentIndexSampler = 0,
} FragmentIndex;


#endif /* ShaderTypes_h */
