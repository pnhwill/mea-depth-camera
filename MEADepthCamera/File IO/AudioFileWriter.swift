//
//  AudioFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/21/21.
//

import AVFoundation
import Combine

/// Helper object that uses AVAssetWriter to record the audio output streams to a file.
class AudioFileWriter<S>: MediaFileWriter<S> where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to audio file", qos: .utility, autoreleaseFrequency: .workItem)
    
    private let audioWriterInput: AVAssetWriterInput
    
    // Publishers and subject
    private let audioDone = PassthroughSubject<Void, Error>()
    
    init(outputURL: URL, configuration: AudioFileConfiguration, subject: S) throws {
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        
        try super.init(name: "AudioFileWriter", outputURL: outputURL, configuration: configuration, subject: subject)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("\(self.description): no audio input added to the audio asset writer")
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
                    print("\(self.description): Error appending sample buffer to audio input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.audioDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("\(self.description): Audio writer input not ready for more media data. Sample dropped without writing to audio file")
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

