//
//  ShaderTypes.h
//  MEADepthCamera
//
//  Created by Will on 7/24/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and Swift sources
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between the Metal shader and Swift code ensure the shader buffer
// inputs match the Metal API buffer set calls.
typedef enum BufferIndex {
    BufferIndexLandmarksInput        = 0,
    BufferIndexCameraIntrinsicsInput = 1,
    BufferIndexPointCloudOutput      = 2,
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

/*
// This structure defines the layout of each vertex in the array of vertices set as an
// input to our Metal vertex shader. Since this header is shared between the Metal shader
// and Swift code, the layout of the vertex array in the code matches the layout that the
// vertex shader expects.
typedef struct {
    // The position for the vertex, in pixel space; a value of 100 indicates 100 pixels
    // from the origin/center.
    packed_float4 position;

    // The 2D texture coordinate for this vertex.
    packed_float2 textureCoordinate;
} Vertex;
*/
#endif /* ShaderTypes_h */
