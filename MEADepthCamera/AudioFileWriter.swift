//
//  AudioFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/21/21.
//

import AVFoundation

enum AudioWriteResult {
    case success
    case failed(Error?)
}

// Helper object that uses AVAssetWriter to record the audio output streams to a file
class AudioFileWriter {
    
    // MARK: Properties
    
    private let audioQueue = DispatchQueue(label: "audio write to audio file", qos: .utility, autoreleaseFrequency: .workItem)
    
    private let audioWriter: AVAssetWriter // Audio only
    private let audioWriterInput: AVAssetWriterInput
    
    init(outputURL: URL, configuration: AudioFileConfiguration) throws {
        audioWriter = try AVAssetWriter(url: outputURL, fileType: configuration.outputFileType)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioCompressionSettings)
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if audioWriter.canAdd(audioWriterInput) {
            audioWriter.add(audioWriterInput)
        } else {
            print("no audio input added to the audio asset writer")
        }
    }
    
    // MARK: Lifecycle Methods
    func start(at startTime: CMTime) {
        guard audioWriter.startWriting() else {
            print("Failed to start writing to audio file")
            return
        }
        //audioWriter.startSession(atSourceTime: CMTime.zero)
        audioWriter.startSession(atSourceTime: startTime)
    }

    func writeAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async {
            if self.audioWriterInput.isReadyForMoreMediaData {
                guard self.audioWriterInput.append(sampleBuffer) else {
                    print("AudioFileWriter: Error appending sample buffer to audio input: \(self.audioWriter.error!.localizedDescription)")
                    return
                }
            } else {
                print("Audio writer input not ready for more media data. Sample dropped without writing to audio file")
            }
        }
    }
    
    // Call this when done transferring audio data.
    // Here you evaluate the final status of the AVAssetWriter.
    func finish(at endTime: CMTime, _ completion: @escaping (AudioWriteResult) -> Void) {
        guard audioWriterInput.isReadyForMoreMediaData else {
            return
        }
        audioWriterInput.markAsFinished()
        //assetWriter.endSession(atSourceTime: endTime)
        audioWriter.finishWriting {
            if self.audioWriter.status == .completed {
                completion(.success)
            } else {
                completion(.failed(self.audioWriter.error))
                print("Error writing audio to file: \(self.audioWriter.error!.localizedDescription)")
            }
        }
    }
}

// MARK: File Compression Settings

struct AudioFileConfiguration {
    
    let outputFileType: AVFileType
    
    // Specify preserve 60fps
    
    let audioCompressionSettings: [String: Any]?
        /*= [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        // For simplicity, hard-code a common sample rate.
        // For a production use case, modify this as necessary to get the desired results given the source content.
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 160_000
    ]*/
    
    init(fileType: AVFileType, audioSettings: [AnyHashable: Any]?) {
        outputFileType = fileType
        //audioCompressionSettings = audioSettings?.filter { $0.key is String } as? [String:Any]
        audioCompressionSettings = audioSettings as? [String: Any]
    }
}
