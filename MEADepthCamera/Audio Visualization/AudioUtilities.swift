//
//  AudioUtilities.swift
//  MEADepthCamera
//
//  Created by Will on 11/27/21.
//

import AVFoundation
import Accelerate

/// Class containing static methods for audio signal processing.
class AudioUtilities {
    
    static let maxFloat = Float(Int16.max)
    static let minFloat = Float(Int16.min)
    
    // MARK: Extract Audio Data
    
    /// Returns an array of 16-bit integer values for the specified audio sample buffer.
    static func getAudioData(_ sampleBuffer: CMSampleBuffer) -> [Int16]? {
        
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
  
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        
        guard let data = audioBufferList.mBuffers.mData else {
            return nil
        }
        
        let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        let ptr = data.bindMemory(to: Int16.self, capacity: actualSampleCount)
        let buf = UnsafeBufferPointer(start: ptr, count: actualSampleCount)
        
        return Array(buf)
    }
    
    // MARK: Audio dB Level
    
    static func peakDecibelLevel(of signal: [Float]) -> Float {
        
        let peakAmplitude = vDSP.maximumMagnitude(signal)
        
        let peakDecibels = vDSP.amplitudeToDecibels([peakAmplitude], zeroReference: maxFloat)
        
        return peakDecibels[0]
    }
    
    static func meanDecibelLevel(of signal: [Float], window: Float, sampleRate: Float) -> [Float] {
        
        let totalSampleCount = Float(signal.count)
        
        let bufferDuration = totalSampleCount / sampleRate
        
        let newWindow = window < bufferDuration ? window : bufferDuration
        
        let sampleCount = Int((totalSampleCount * newWindow / bufferDuration).rounded(.up))
        
        let windows = signal.chunked(into: sampleCount)
//        let remainder = windows.popLast()
        
        let meanAmplitudes = windows.map { vDSP.meanMagnitude($0) }
        
        let meanDecibels = vDSP.amplitudeToDecibels(meanAmplitudes, zeroReference: maxFloat)
        
        return meanDecibels
    }
    
}


