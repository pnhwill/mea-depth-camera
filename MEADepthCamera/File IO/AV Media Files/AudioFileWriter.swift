//
//  AudioFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/21/21.
//

import AVFoundation
import Combine

/// Helper object that uses AVAssetWriter to record the audio output streams to a file.
class AudioFileWriter: MediaFileWriter<CapturePipeline.FileWriterSubject> {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("\(typeName).audioQueue"),
        qos: .utility,
        autoreleaseFrequency: .workItem)
    
    private let audioWriterInput: AVAssetWriterInput
    
    // Publishers and subject
    private let audioDone = PassthroughSubject<Void, Error>()
    
    init(folderURL: URL, configuration: AudioFileConfiguration, subject: CapturePipeline.FileWriterSubject) throws {
        audioWriterInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: configuration.audioSettings)
        
        try super.init(outputType: .audio, folderURL: folderURL, configuration: configuration, subject: subject)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            logger.error("\(self.typeName): No audio input added to the audio asset writer.")
        }
        
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = audioDone.sink(receiveCompletion: { [weak self] completion in
            self?.finish(completion: completion)
        }, receiveValue: { _ in })
    }
    
    // MARK: Media Writing Methods

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
                self.logger.notice("\(self.typeName): Audio writer input not ready for more media data. Sample dropped without writing to audio file.")
            }
        }
    }
    
    // MARK: End Recording Call
    func endRecording() {
        writeState = .inactive
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

