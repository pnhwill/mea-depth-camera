//
//  PointCloudMetalRenderer.h
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

#ifndef PointCloudMetalRenderer_h
#define PointCloudMetalRenderer_h

//#import <MetalKit/MetalKit.h>
//#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVDepthData.h>
//#import <CoreGraphics/CGGeometry.h>
#import <Foundation/NSArray.h>

@interface PointCloudMetalRenderer : NSObject

- (nonnull instancetype)init;

// Update depth frame and landmarks
- (void)setDepthFrame:(AVDepthData* _Nonnull)depth withLandmarks:(NSArray* _Nonnull)landmarks;

// Return point cloud output
- (vector_float3* _Nonnull)getOutput;

@end

#endif /* PointCloudMetalRenderer_h */
