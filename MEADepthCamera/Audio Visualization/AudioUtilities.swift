//
//  AudioUtilities.swift
//  MEADepthCamera
//
//  Created by Will on 11/27/21.
//

import AVFoundation
import Accelerate

/// Class containing methods for audio signal processing.
class AudioUtilities {
    
    /// Returns an array of single-precision values for the specified audio sample buffer.
    static func getAudioSamples(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
        
        if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
            let count = bufferLength / 4
            
            let data = [Float](unsafeUninitializedCapacity: count) {
                buffer, initializedCount in
                
                CMBlockBufferCopyDataBytes(dataBuffer,
                                           atOffset: 0,
                                           dataLength: bufferLength,
                                           destination: buffer.baseAddress!)
                
                initializedCount = count
            }
            
            return data
        } else {
            return nil
        }
    }
}
