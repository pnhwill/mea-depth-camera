//
//  getNumberOfFrames.m
//  MEADepthCamera
//
//  Created by Will on 8/3/21.
//
/*
 Abstract:
 Fast implementation to get total number of frames in a video file.
 
 Reference: https://stackoverflow.com/questions/13645306/get-number-of-frames-in-a-video-via-avfoundation
 */

#import <AVFoundation/AVFoundation.h>

int getNumberOfFrames(NSURL *url)
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:nil];

    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    [assetReader addOutput:readerVideoTrackOutput];

    [assetReader startReading];

    int nframes = 0;
    for (;;)
    {
        CMSampleBufferRef buffer = [readerVideoTrackOutput copyNextSampleBuffer];
        if (buffer == NULL)
        {
            break;
        }

        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(buffer);
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
        if (mediaType == kCMMediaType_Video)
        {
            nframes++;
        }

        CFRelease(buffer);
    }

    return nframes;
}
