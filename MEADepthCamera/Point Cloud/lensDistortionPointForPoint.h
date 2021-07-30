//
//  lensDistortionPointForPoint.h
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

#ifndef lensDistortionPointForPoint_h
#define lensDistortionPointForPoint_h

#import <CoreGraphics/CGGeometry.h>

CGPoint lensDistortionPointForPoint(CGPoint point, NSData *lookupTable, CGPoint opticalCenter, CGSize imageSize);

#endif /* lensDistortionPointForPoint_h */
