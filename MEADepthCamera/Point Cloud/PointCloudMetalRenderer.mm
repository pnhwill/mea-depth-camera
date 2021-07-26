//
//  PointCloudMetalRenderer.m
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class implementing point cloud rendering
*/

#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <Foundation/Foundation.h>
#include "PointCloudMetalRenderer.h"
#include <simd/simd.h>
#import <CoreGraphics/CGGeometry.h>
// Header shared between C code, which executes Metal API commands, and .metal files,
// which use these types as inputs to the shaders.
#import "ShaderTypes.h"

static int const numLandmarks = 76;

@implementation PointCloudMetalRenderer {
    dispatch_queue_t _syncQueue;
    AVDepthData* _internalDepthFrame;
    CVMetalTextureCacheRef _depthTextureCache;
    NSArray* _internalLandmarks;
    
    id<MTLDevice> _device;
    
    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;
    
    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _renderPipelineState;
    
    // Buffers to hold data.
    id<MTLBuffer> _pointCloudBuffer;
}

- (nonnull instancetype)init {
    dispatch_queue_attr_t attr = NULL;
    attr = dispatch_queue_attr_make_with_autorelease_frequency(attr, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM);
    attr = dispatch_queue_attr_make_with_qos_class(attr, QOS_CLASS_USER_INITIATED, 0);
    _syncQueue = dispatch_queue_create("PointCloudMetalRenderer sync queue", attr);
    
    _device = MTLCreateSystemDefaultDevice();
    
    [self configureMetal];
    
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_depthTextureCache);
    
    return self;
}

- (void)configureMetal {
    
    // Load all the shader files with a metal file extension in the project
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    // Load the vertex function from the library
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShaderPoints"];
    
    // Set up a descriptor for creating a pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Rendering Pipeline";
    pipelineStateDescriptor.rasterizationEnabled = false;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = nil;
    pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    NSError *error = NULL;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                       error:&error];

    if (!_renderPipelineState)
    {
        // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
        // If the Metal API validation is enabled, we can find out more information about what
        // went wrong.  (Metal API validation is enabled by default when a debug build is run
        // from Xcode)
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    
    // Create the command queue
    _commandQueue = [_device newCommandQueue];
}

- (void)setDepthFrame:(AVDepthData* _Nonnull)depth withLandmarks:(NSArray* _Nonnull)landmarks {
    dispatch_sync(_syncQueue, ^{
        self->_internalDepthFrame = depth;
        self->_internalLandmarks = landmarks;
    });
    
    // add completion handler?
    dispatch_async(dispatch_get_main_queue(), ^{
        [self render];
    });
}

- (void)render {
    __block AVDepthData* depthData = nil;
    __block NSArray* landmarks = nil;
    
    dispatch_sync(_syncQueue, ^{
        depthData = self->_internalDepthFrame;
        landmarks = self->_internalLandmarks;
    });
    
    if (depthData == nil || landmarks == nil)
        return;
    
    // Create a Metal texture from the depth frame
    CVPixelBufferRef depthFrame = depthData.depthDataMap;
    CVMetalTextureRef cvDepthTexture = nullptr;
    if (kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                            _depthTextureCache,
                            depthFrame,
                            nil,
                            MTLPixelFormatR16Float,
                            CVPixelBufferGetWidth(depthFrame),
                            CVPixelBufferGetHeight(depthFrame),
                            0,
                            &cvDepthTexture)) {
        NSLog(@"Failed to create depth texture");
        return;
    }
    
    id<MTLTexture> depthTexture = CVMetalTextureGetTexture(cvDepthTexture);
    
    // Get camera instrinsics
    matrix_float3x3 intrinsics = depthData.cameraCalibrationData.intrinsicMatrix;
    CGSize referenceDimensions = depthData.cameraCalibrationData.intrinsicMatrixReferenceDimensions;
    
    // Bring focal and principal points into the same coordinate system as the depth map
    float ratio = referenceDimensions.width / CVPixelBufferGetWidth(depthFrame);
    intrinsics.columns[0][0] /= ratio;
    intrinsics.columns[1][1] /= ratio;
    intrinsics.columns[2][0] /= ratio;
    intrinsics.columns[2][1] /= ratio;
    
    // Create a new command buffer for each renderpass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
    
    MTLTextureDescriptor* depthTextureDescriptor = [[MTLTextureDescriptor alloc] init];
    depthTextureDescriptor.width = 1;
    depthTextureDescriptor.height = 1;
    depthTextureDescriptor.pixelFormat = MTLPixelFormatDepth32Float;
    depthTextureDescriptor.usage = MTLTextureUsageRenderTarget;
    
    id<MTLTexture> depthTestTexture = [_device newTextureWithDescriptor:depthTextureDescriptor];

    renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    renderPassDescriptor.depthAttachment.clearDepth = 1.0;
    renderPassDescriptor.depthAttachment.texture = depthTestTexture;
    
    // Create render encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor: renderPassDescriptor];
    [renderEncoder setRenderPipelineState: _renderPipelineState];
    
    // Set up input buffer
    size_t inBufferSize = sizeof(vector_float2) * numLandmarks;
    id<MTLBuffer> inputBuffer = [_device newBufferWithBytes: &landmarks length: inBufferSize options: MTLStorageModeShared];
    
    // Set up output buffer for vertex shader to write point cloud data into
    size_t outBufferSize = sizeof(vector_float3) * numLandmarks;
    id<MTLBuffer> outputBuffer = [_device newBufferWithLength: outBufferSize options: MTLStorageModeShared];
    
    // Set arguments to shader
    [renderEncoder setVertexBuffer: inputBuffer offset: 0 atIndex: VertexInputIndexLandmarks];
    [renderEncoder setVertexTexture: depthTexture atIndex: TextureIndexDepthInput];
    [renderEncoder setVertexBytes: &intrinsics length: sizeof(intrinsics) atIndex: VertexInputIndexCameraIntrinsics];
    [renderEncoder setVertexBuffer: outputBuffer offset: 0 atIndex: VertexInputIndexPointCloud];
    
    [renderEncoder drawPrimitives: MTLPrimitiveTypePoint
                      vertexStart: 0
                      vertexCount: numLandmarks];
    
    [renderEncoder endEncoding];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
    
    CFRelease(cvDepthTexture);
    
    self->_pointCloudBuffer = outputBuffer;
}
/*
- (vector_float3* _Nonnull)getOutput {
    vector_float3* output = (vector_float3*)_pointCloudBuffer.contents;
    return output;
}
*/
/*
- (vector_float2)convertArray: (NSArray*)landmarkVectors {
    
    NSRange range = NSMakeRange(0, numLandmarks);
    id *objects = (id*)malloc(sizeof(id) * numLandmarks);
    
    [landmarkVectors getObjects: objects range: range];
    
    return objects;
}
*/

@end
