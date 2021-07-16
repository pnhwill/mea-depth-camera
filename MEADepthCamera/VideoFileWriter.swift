//
//  VideoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/15/21.
//

import AVFoundation
import Photos

enum VideoWriteResult {
    case success
    case failed(Error?)
}

// Helper object that uses AVAssetWriter to record the video and audio output streams to a file
class VideoFileWriter {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write", qos: .utility, autoreleaseFrequency: .workItem)
    private let videoQueue = DispatchQueue(label: "video write", qos: .utility, autoreleaseFrequency: .workItem)
    
    private let assetWriter: AVAssetWriter
    private let audioWriterInput: AVAssetWriterInput
    private let videoWriterInput: AVAssetWriterInput
    //private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    var location: CLLocation?
    
    init(outputURL: URL, configuration: VideoFileConfiguration) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioCompressionSettings)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoCompressionSettings)
        //pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        let rotation: CGFloat = 90
        let affineTransform = CGAffineTransform(rotationAngle: rotation.radiansForDegrees())
        videoWriterInput.transform = affineTransform
        
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            print("no video input added to the asset writer")
        }
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("no audio input added to the asset writer")
        }
    }
    
    func start(at startTime: CMTime) {
        guard assetWriter.startWriting() else {
            print("Failed to start writing to video file")
            return
        }
        assetWriter.startSession(atSourceTime: startTime)
    }
    
    func writeVideo(_ sampleBuffer: CMSampleBuffer) {
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.videoWriterInput.append(sampleBuffer) else {
                    debugPrint("Error appending pixel buffer to adaptor: \(self.assetWriter.error?.localizedDescription as String?)")
                    return
                }
            } else {
                print("Video writer input not ready for more media data. Sample dropped without writing to file")
            }
        }
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    print("Error appending sample buffer to input: \(self.assetWriter.error?.localizedDescription as String?)")
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to file")
            }
        }
    }
    
    // Call this when done transferring audio and video data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (VideoWriteResult) -> Void) {
        guard videoWriterInput.isReadyForMoreMediaData, audioWriterInput.isReadyForMoreMediaData else {
            return
        }
        audioWriterInput.markAsFinished()
        videoWriterInput.markAsFinished()
        //assetWriter.endSession(atSourceTime: endTime)
        assetWriter.finishWriting {
            if self.assetWriter.status == .completed {
                completion(.success)
            } else {
                completion(.failed(self.assetWriter.error))
                print("Error writing video/audio to file: \(self.assetWriter.error?.localizedDescription as String?)")
            }
        }
    }
    
}

struct VideoFileConfiguration {
    
    let outputFileType: AVFileType
    
    let videoCompressionSettings: [String: Any]?
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
    
    // Specify preserve 60fps
    
    let audioCompressionSettings: [String: Any]?
        /*= [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        // For simplicity, hard-code a common sample rate.
        // For a production use case, modify this as necessary to get the desired results given the source content.
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 160_000
    ]*/
    
    init(fileType: AVFileType, videoSettings: [String: Any]?, audioSettings: [AnyHashable: Any]?) {
        outputFileType = fileType
        videoCompressionSettings = videoSettings
        //audioCompressionSettings = audioSettings?.filter { $0.key is String } as? [String:Any]
        audioCompressionSettings = audioSettings as? [String: Any]
    }
}
