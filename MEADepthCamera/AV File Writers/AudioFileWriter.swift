//
//  AudioFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/21/21.
//

import AVFoundation
import Combine

// Helper object that uses AVAssetWriter to record the audio output streams to a file
class AudioFileWriter<S>: FileWriter where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to audio file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Audio only
    private let audioWriterInput: AVAssetWriterInput
    
    var writeState = WriteState.inactive
    
    // Publishers and subject
    private let audioDone = PassthroughSubject<Void, Error>()
    var done: AnyCancellable?
    let subject: S
    
    required init(outputURL: URL, configuration: AudioFileConfiguration, subject: S) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("no audio input added to the audio asset writer")
        }
        
        self.subject = subject
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = audioDone.sink(receiveCompletion: { [weak self] completion in
            self?.finish(completion: completion)
        }, receiveValue: { _ in })
    }
    
    // MARK: Lifecycle Methods
    func start(at startTime: CMTime) {
        writeState = .active
        guard assetWriter.startWriting() else {
            print("Failed to start writing to audio file")
            switch self.assetWriter.status {
            case .failed:
                subject.send(completion: .failure(self.assetWriter.error!))
            default:
                let error = FileWriterError.getErrorForStatus(of: self.assetWriter)
                subject.send(completion: .failure(error))
            }
            return
        }
        assetWriter.startSession(atSourceTime: startTime)
        
        subject.send(writeState)
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    print("AudioFileWriter: Error appending sample buffer to audio input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.audioDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to audio file")
            }
        }
    }
    
    // Call this when done transferring audio data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .failure:
            assetWriter.cancelWriting()
            subject.send(completion: completion)
        default:
            assetWriter.finishWriting {
                switch self.assetWriter.status {
                case .completed:
                    self.subject.send(completion: .finished)
                case .failed:
                    self.subject.send(completion: .failure(self.assetWriter.error!))
                default:
                    let error = FileWriterError.getErrorForStatus(of: self.assetWriter)
                    self.subject.send(completion: .failure(error))
                }
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

