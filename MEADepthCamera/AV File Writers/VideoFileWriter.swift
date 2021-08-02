//
//  VideoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/15/21.
//

import AVFoundation
import Combine

// Helper object that uses AVAssetWriter to record the video and audio output streams to a file
class VideoFileWriter<S>: FileWriter where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    private let videoQueue = DispatchQueue(label: "video write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Audio and video
    private let audioWriterInput: AVAssetWriterInput
    private let videoWriterInput: AVAssetWriterInput
    
    // Publishers and subject
    private let audioDone = PassthroughSubject<Void, Error>()
    private let videoDone = PassthroughSubject<Void, Error>()
    var done: AnyCancellable?
    let subject: S
    
    var writeState = WriteState.inactive
    
    required init(outputURL: URL, configuration: VideoFileConfiguration, subject: S) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
        //pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        videoWriterInput.transform = configuration.videoTransform
        
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
        
        self.subject = subject
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = audioDone.combineLatest(videoDone)
            .sink(receiveCompletion: { [weak self] completion in
                self?.finish(completion: completion)
            }, receiveValue: { _ in })
    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        writeState = .active
        guard assetWriter.startWriting() else {
            print("Failed to start writing to video file")
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
    
    func writeVideo(_ sampleBuffer: CMSampleBuffer) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.videoWriterInput.append(sampleBuffer) else {
                    print("Error appending sample buffer to video input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.videoDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("Video writer input not ready for more media data. Sample dropped without writing to video file")
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
                    print("Error appending sample buffer to audio input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.audioDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to video file")
            }
        }
    }
    
    // Call this when done transferring audio and video data.
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

