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
}
