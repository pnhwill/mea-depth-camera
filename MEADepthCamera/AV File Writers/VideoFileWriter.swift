//
//  VideoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/15/21.
//

import AVFoundation

// Helper object that uses AVAssetWriter to record the video and audio output streams to a file
class VideoFileWriter: FileWriter {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    private let videoQueue = DispatchQueue(label: "video write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Audio and video
    private let audioWriterInput: AVAssetWriterInput
    private let videoWriterInput: AVAssetWriterInput
    //private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    required init(outputURL: URL, configuration: VideoFileConfiguration) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
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
            print("no video input added to the video asset writer")
        }
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("no audio input added to the video asset writer")
        }
    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        guard assetWriter.startWriting() else {
            print("Failed to start writing to video file")
            return
        }
        //videoWriter.startSession(atSourceTime: CMTime.zero)
        assetWriter.startSession(atSourceTime: startTime)
    }
    
    func writeVideo(_ sampleBuffer: CMSampleBuffer) {
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.videoWriterInput.append(sampleBuffer) else {
                    print("Error appending sample buffer to video input: \(self.assetWriter.error!.localizedDescription)")
                    return
                }
            } else {
                print("Video writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    print("Error appending sample buffer to audio input: \(self.assetWriter.error!.localizedDescription)")
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }
    
    // Call this when done transferring audio and video data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (FileWriteResult) -> Void) {
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
                print("Error writing video/audio to file: \(self.assetWriter.error!.localizedDescription)")
            }
        }
    }
}

