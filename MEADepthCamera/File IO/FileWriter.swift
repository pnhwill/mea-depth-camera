//
//  FileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation
import Combine

// This implements a protocol for all file writers

protocol FileWriter: AnyObject {
    /*
    associatedtype OutputSettings: FileConfiguration
    associatedtype S: Subject
    
    var assetWriter: AVAssetWriter { get }
    
    var writeState: WriteState { get set }
    
    var done: AnyCancellable? { get set }
    var subject: S { get }
    
    init(outputURL: URL, configuration: OutputSettings, subject: S) throws
    
    func start(at startTime: CMTime)
    
    func finish(completion: Subscribers.Completion<Error>)
    */
}

protocol CSVFileWriter: FileWriter {
    
}

// Abstract superclass for all video/audio/depth data file writers
class MediaFileWriter<S>: FileWriter where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    // MARK: Properties
    
    let description: String
    
    // Asset Writer
    let assetWriter: AVAssetWriter
    
    // Publishers and subject
    let subject: S
    var done: AnyCancellable?
    
    // File writer state
    var writeState = WriteState.inactive
    
    init(name: String, outputURL: URL, configuration: FileConfiguration, subject: S) throws {
        self.assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        self.description = name
        self.subject = subject
    }
    
//    deinit {
//        print("deinitializing \(description)")
//    }
    
    // MARK: Lifecycle Methods
    
    func start(at startTime: CMTime) {
        writeState = .active
        guard assetWriter.startWriting() else {
            print("\(description): Failed to start writing to file")
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
    
    
}
