//
//  DepthMapFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//

import AVFoundation

// Helper object that uses AVAssetWriter to record the depth map output streams to a file
class DepthMapFileWriter: FileWriter {
    
    // MARK: Properties
    
    private let videoQueue = DispatchQueue(label: "depth map write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Video only
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    required init(outputURL: URL, configuration: DepthMapFileConfiguration) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: configuration.pixelBufferAttributes)
        
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        let rotation: CGFloat = 90
        let affineTransform = CGAffineTransform(rotationAngle: rotation.radiansForDegrees())
        videoWriterInput.transform = affineTransform
        
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            print("DepthMapFileWriter: no video input added to the video asset writer")
        }
    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        guard assetWriter.startWriting() else {
            print("DepthMapFileWriter: Failed to start writing to video file")
            return
        }
        //videoWriter.startSession(atSourceTime: CMTime.zero)
        assetWriter.startSession(atSourceTime: startTime)
    }
    
    func writeVideo(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: timeStamp) else {
                    print("DepthMapFileWriter: Error appending pixel buffer to video input: \(self.assetWriter.error!.localizedDescription)")
                    return
                }
            } else {
                print("DepthMapFileWriter: Video writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }
    
    // Call this when done transferring audio and video data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (FileWriteResult) -> Void) {
        guard videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        videoWriterInput.markAsFinished()
        //assetWriter.endSession(atSourceTime: endTime)
        assetWriter.finishWriting {
            if self.assetWriter.status == .completed {
                completion(.success)
            } else {
                completion(.failed(self.assetWriter.error))
                print("DepthMapFileWriter: Error writing video/audio to file: \(self.assetWriter.error!.localizedDescription)")
            }
        }
    }
}

