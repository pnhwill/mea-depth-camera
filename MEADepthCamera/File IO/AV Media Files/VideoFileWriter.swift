//
//  VideoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/15/21.
//

import AVFoundation
import Combine

/// Helper object that uses AVAssetWriter to record the video and audio output streams to a file.
class VideoFileWriter: MediaFileWriter<CapturePipeline.FileWriterSubject> {
    
    // MARK: Properties
    private let audioQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("\(typeName).audioQueue"),
        qos: .utility,
        autoreleaseFrequency: .workItem)
    private let videoQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("\(typeName).videoQueue"),
        qos: .utility,
        autoreleaseFrequency: .workItem)
    
    private let audioWriterInput: AVAssetWriterInput
    private let videoWriterInput: AVAssetWriterInput
    
    // Publishers and subject
    private let audioDone = PassthroughSubject<Void, Error>()
    private let videoDone = PassthroughSubject<Void, Error>()
    
    init(folderURL: URL, configuration: VideoFileConfiguration, subject: CapturePipeline.FileWriterSubject) throws {
        audioWriterInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: configuration.audioSettings)
        videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: configuration.videoSettings,
            sourceFormatHint: configuration.sourceVideoFormat)
        
        try super.init(outputType: .video, folderURL: folderURL, configuration: configuration, subject: subject)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        videoWriterInput.transform = configuration.videoTransform
        
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            logger.error("\(self.typeName): No video input added to the video asset writer.")
        }
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            logger.error("\(self.typeName): No audio input added to the video asset writer.")
        }
        
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = audioDone.combineLatest(videoDone)
            .sink(receiveCompletion: { [weak self] completion in
                self?.finish(completion: completion)
            }, receiveValue: { _ in })
    }
    
    // MARK: Media Writing Methods
    
    func writeVideo(_ sampleBuffer: CMSampleBuffer) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.videoWriterInput.append(sampleBuffer) else {
                    self.logger.error("\(self.typeName): Error appending sample buffer to video input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.videoDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                self.logger.notice("\(self.typeName): Video writer input not ready for more media data. Sample dropped without writing to video file.")
            }
        }
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    self.logger.error("\(self.typeName): Error appending sample buffer to audio input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.audioDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                self.logger.notice("\(self.typeName): Audio writer input not ready for more media data. Sample dropped without writing to video file.")
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
        audioQueue.async {
            while true {
                if let completion = self.checkWriterInput(writerInput: self.audioWriterInput) {
                    self.audioWriterInput.markAsFinished()
                    self.audioDone.send(completion: completion)
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

