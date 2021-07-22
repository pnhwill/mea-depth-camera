//
//  DepthMapFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//

import AVFoundation

enum DepthMapWriteResult {
    case success
    case failed(Error?)
}

// Helper object that uses AVAssetWriter to record the depth map output streams to a file
class DepthMapFileWriter {
    
    // MARK: Properties
    
    private let videoQueue = DispatchQueue(label: "depth map write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    
    private let videoWriter: AVAssetWriter // Video only
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    init(outputURL: URL, configuration: DepthMapFileConfiguration) throws {
        videoWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: configuration.pixelBufferAttributes)
        
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        let rotation: CGFloat = 90
        let affineTransform = CGAffineTransform(rotationAngle: rotation.radiansForDegrees())
        videoWriterInput.transform = affineTransform
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        } else {
            print("DepthMapFileWriter: no video input added to the video asset writer")
        }
    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        guard videoWriter.startWriting() else {
            print("DepthMapFileWriter: Failed to start writing to video file")
            return
        }
        //videoWriter.startSession(atSourceTime: CMTime.zero)
        videoWriter.startSession(atSourceTime: startTime)
    }
    
    func writeVideo(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: timeStamp) else {
                    print("DepthMapFileWriter: Error appending pixel buffer to video input: \(self.videoWriter.error!.localizedDescription)")
                    return
                }
            } else {
                print("DepthMapFileWriter: Video writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }
    
    // Call this when done transferring audio and video data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (VideoWriteResult) -> Void) {
        guard videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        videoWriterInput.markAsFinished()
        //assetWriter.endSession(atSourceTime: endTime)
        videoWriter.finishWriting {
            if self.videoWriter.status == .completed {
                completion(.success)
            } else {
                completion(.failed(self.videoWriter.error))
                print("DepthMapFileWriter: Error writing video/audio to file: \(self.videoWriter.error!.localizedDescription)")
            }
        }
    }
}

// MARK: File Compression Settings

struct DepthMapFileConfiguration {
    
    let outputFileType: AVFileType
    
    var videoSettings: [String: Any]?
        /*= [
        AVVideoCodecKey: AVVideoCodecType.h264,
        // For simplicity, assume 16:9 aspect ratio.
        // For a production use case, modify this as necessary to match the source content.
        AVVideoWidthKey: 1920,
        AVVideoHeightKey: 1080,
        AVVideoCompressionPropertiesKey: [
            kVTCompressionPropertyKey_AverageBitRate: 6_000_000,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_4_2
        ]
    ]*/
    
    // Specify preserve 30fps
    
    var pixelBufferAttributes: [String: Any]?
    
    init(fileType: AVFileType, videoSettings: [String: Any]?) {
        self.outputFileType = fileType
        self.videoSettings = videoSettings
        self.videoSettings?["AVVideoHeightKey"] = 480
        self.videoSettings?["AVVideoWidthKey"] = 640
        //print(self.videoSettings)
        self.pixelBufferAttributes = nil
    }
}


