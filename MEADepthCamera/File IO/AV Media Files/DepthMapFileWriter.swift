//
//  DepthMapFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//

import AVFoundation
import Combine

/// Helper object that uses AVAssetWriter to record the depth map output streams to a file.
class DepthMapFileWriter: MediaFileWriter<CapturePipeline.FileWriterSubject> {
    
    // MARK: Properties
    
    private let videoQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("\(typeName).videoQueue"),
        qos: .utility,
        autoreleaseFrequency: .workItem)
    
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    // Publishers and subject
    private let videoDone = PassthroughSubject<Void, Error>()
    
    required init(folderURL: URL, configuration: DepthMapFileConfiguration, subject: CapturePipeline.FileWriterSubject) throws {
        videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: configuration.videoSettings,
            sourceFormatHint: configuration.sourceVideoFormat)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: configuration.sourcePixelBufferAttributes)
        
        try super.init(outputType: .depth, folderURL: folderURL, configuration: configuration, subject: subject)
        
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        videoWriterInput.transform = configuration.videoTransform
        
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            print("\(typeName): no video input added to the video asset writer")
        }
        
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = videoDone.sink(receiveCompletion: { [weak self] completion in
            self?.finish(completion: completion)
        }, receiveValue: { _ in })
    }
    
    // MARK: Media Writing Methods
    
    func writeVideo(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: timeStamp) else {
                    print("\(self.typeName): Error appending pixel buffer to video input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.videoDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("\(self.typeName): Video writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }
    
    // MARK: End Recording Call
    func endRecording() {
        writeState = .inactive
        videoQueue.async {
            while true {
                if let completion = self.checkWriterInput(writerInput: self.videoWriterInput) {
                    self.videoWriterInput.markAsFinished()
                    self.videoDone.send(completion: completion)
                    break
                }
            }
        }
    }
    func checkWriterInput(writerInput: AVAssetWriterInput) -> Subscribers.Completion<Error>? {
        if writerInput.isReadyForMoreMediaData {
            return .finished
        } else {
            return nil
        }
    }
}

