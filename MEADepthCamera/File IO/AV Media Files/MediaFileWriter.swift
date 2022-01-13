//
//  MediaFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 12/9/21.
//

import AVFoundation
import Combine
import OSLog

enum WriteState {
    case inactive, active
}

enum FileWriteResult {
    case success
    case failed(Error?)
}

// MARK: MediaFileWriter

/// Abstract superclass for all video/audio/depth data file writers.
class MediaFileWriter<S>: FileWriter where S: Subject, S.Output == WriteState, S.Failure == Error {
    
    let outputType: OutputType
    let fileURL: URL
    
    // Asset Writer
    let assetWriter: AVAssetWriter
    
    // Publishers and subject
    let subject: S
    var done: AnyCancellable?
    
    // File writer state
    var writeState = WriteState.inactive
    
    let logger = Logger.Category.fileIO.logger
    
    init(outputType: OutputType, folderURL: URL, configuration: FileConfiguration, subject: S) throws {
        let fileURL = Self.createFileURL(in: folderURL, outputType: outputType)
        self.outputType = outputType
        self.fileURL = fileURL
        self.assetWriter = try AVAssetWriter(url: fileURL, fileType: configuration.outputFileType)
        self.subject = subject
    }
    
    // MARK: Start/Finish Methods
    
    func start(at startTime: CMTime) {
        writeState = .active
        guard assetWriter.startWriting() else {
            logger.error("\(self.typeName): Failed to start writing to file.")
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
        logger.notice("\(self.typeName) is ready to start writing to file(s).")
        subject.send(writeState)
    }
    
    /// Call this when done transferring audio and video data.
    ///
    /// Here you evaluate the final status of the AVAssetWriter.
    func finish(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .failure:
            assetWriter.cancelWriting()
            subject.send(completion: completion)
        default:
            assetWriter.finishWriting {
                switch self.assetWriter.status {
                case .completed:
                    self.logger.notice("\(self.typeName) successfully finished writing.")
                    self.subject.send(completion: .finished)
                case .failed:
                    self.logger.error("\(self.typeName) failed to finish writing.")
                    self.subject.send(completion: .failure(self.assetWriter.error!))
                default:
                    let error = FileWriterError.getErrorForStatus(of: self.assetWriter)
                    self.logger.error("\(self.typeName) finished writing with error: \(error.localizedDescription).")
                    self.subject.send(completion: .failure(error))
                }
            }
        }
    }
}

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
