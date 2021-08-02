//
//  DepthMapFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//

import AVFoundation
import Combine

// Helper object that uses AVAssetWriter to record the depth map output streams to a file
class DepthMapFileWriter<S>: FileWriter where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    // MARK: Properties
    
    private let description = "DepthMapFileWriter"
    
    private let videoQueue = DispatchQueue(label: "depth map write to video file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Video only
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    var writeState = WriteState.inactive
    
    // Publishers and subject
    private let videoDone = PassthroughSubject<Void, Error>()
    var done: AnyCancellable?
    let subject: S
    
    required init(outputURL: URL, configuration: DepthMapFileConfiguration, subject: S) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: configuration.pixelBufferAttributes)
        
        videoWriterInput.expectsMediaDataInRealTime = true
        
        // Rotate the video into upright orientation.
        videoWriterInput.transform = configuration.videoTransform
        
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            print("\(description): no video input added to the video asset writer")
        }
        
        self.subject = subject
        // The audio track and video track are transfered to the writer in parallel.
        // Wait until both are finished, then finish the whole operation.
        done = videoDone.sink(receiveCompletion: { [weak self] completion in
            self?.finish(completion: completion)
        }, receiveValue: { _ in })
    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        writeState = .active
        guard assetWriter.startWriting() else {
            print("\(description): Failed to start writing to video file")
            return
        }
        //videoWriter.startSession(atSourceTime: CMTime.zero)
        assetWriter.startSession(atSourceTime: startTime)
        
        subject.send(writeState)
    }
    
    func writeVideo(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        guard writeState == .active, assetWriter.status == .writing else {
            return
        }
        videoQueue.async {
            if self.videoWriterInput.isReadyForMoreMediaData {
                guard self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: timeStamp) else {
                    print("\(self.description): Error appending pixel buffer to video input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    self.videoDone.send(completion: .failure(self.assetWriter.error!))
                    return
                }
            } else {
                print("\(self.description): Video writer input not ready for more media data. Sample dropped without writing to video file")
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
    }
    func checkWriterInput(writerInput: AVAssetWriterInput) -> Subscribers.Completion<Error>? {
        if writerInput.isReadyForMoreMediaData {
            return .finished
        } else {
            return nil
        }
    }
}

