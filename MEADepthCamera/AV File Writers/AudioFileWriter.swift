//
//  AudioFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/21/21.
//

import AVFoundation

// Helper object that uses AVAssetWriter to record the audio output streams to a file
class AudioFileWriter: FileWriter {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to audio file", qos: .utility, autoreleaseFrequency: .workItem)
    
    let assetWriter: AVAssetWriter // Audio only
    private let audioWriterInput: AVAssetWriterInput
    
    required init(outputURL: URL, configuration: AudioFileConfiguration) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("no audio input added to the audio asset writer")
        }
    }
    
    // MARK: Lifecycle Methods
    func start(at startTime: CMTime) {
        guard assetWriter.startWriting() else {
            print("Failed to start writing to audio file")
            return
        }
        //audioWriter.startSession(atSourceTime: CMTime.zero)
        assetWriter.startSession(atSourceTime: startTime)
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    print("AudioFileWriter: Error appending sample buffer to audio input: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to audio file")
            }
        }
    }
    
    // Call this when done transferring audio data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (FileWriteResult) -> Void) {
        guard audioWriterInput.isReadyForMoreMediaData else {
            return
        }
        audioWriterInput.markAsFinished()
        //assetWriter.endSession(atSourceTime: endTime)
        assetWriter.finishWriting {
            if self.assetWriter.status == .completed {
                completion(.success)
            } else {
                completion(.failed(self.assetWriter.error))
                print("Error writing audio to file: \(self.assetWriter.error?.localizedDescription ?? "error unknown")")
            }
        }
    }
}

