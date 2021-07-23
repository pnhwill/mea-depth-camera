//
//  FileConfigurations.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation

// This implements a standard file configuration format for all AV file writers
// NOTE: could use AVOutputSettingsAssistant for this

protocol FileConfiguration {
    var outputFileType: AVFileType { get }
}

// MARK: Video File

struct VideoFileConfiguration: FileConfiguration {
    
    let outputFileType: AVFileType
    
    let videoSettings: [String: Any]?
        /*= [
        AVVideoCodecKey: AVVideoCodecType.h264,
        // For simplicity, assume 16:9 aspect ratio.
        // For a production use case, modify this as necessary to match the source content.
        AVVideoWidthKey: 1920,
        AVVideoHeightKey: 1080,
        AVVideoCompressionPropertiesKey: [
            kVTCompressionPropertyKey_AverageBitRate: 6_000_000,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_4_2
        ]
    ]*/
    
    // Specify preserve 60fps
    
    let audioSettings: [String: Any]?
        /*= [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        // For simplicity, hard-code a common sample rate.
        // For a production use case, modify this as necessary to get the desired results given the source content.
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 160_000
    ]*/
    
    init(fileType: AVFileType, videoSettings: [String: Any]?, audioSettings: [AnyHashable: Any]?) {
        self.outputFileType = fileType
        self.videoSettings = videoSettings
        //self.audioSettings = audioSettings?.filter { $0.key is String } as? [String:Any]
        self.audioSettings = audioSettings as? [String: Any]
    }
}

// MARK: Audio File

struct AudioFileConfiguration: FileConfiguration {
    
    let outputFileType: AVFileType
    
    // Specify preserve 60fps
    
    let audioSettings: [String: Any]?
        /*= [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        // For simplicity, hard-code a common sample rate.
        // For a production use case, modify this as necessary to get the desired results given the source content.
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 160_000
    ]*/
    
    init(fileType: AVFileType, audioSettings: [AnyHashable: Any]?) {
        self.outputFileType = fileType
        //self.audioSettings = audioSettings?.filter { $0.key is String } as? [String:Any]
        self.audioSettings = audioSettings as? [String: Any]
    }
}

// MARK: Depth Map File

struct DepthMapFileConfiguration: FileConfiguration {
    
    let outputFileType: AVFileType
    
    var videoSettings: [String: Any]?
        /*= [
        AVVideoCodecKey: AVVideoCodecType.h264,
        // For simplicity, assume 16:9 aspect ratio.
        // For a production use case, modify this as necessary to match the source content.
        AVVideoWidthKey: 1920,
        AVVideoHeightKey: 1080,
        AVVideoCompressionPropertiesKey: [
            kVTCompressionPropertyKey_AverageBitRate: 6_000_000,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_4_2
        ]
    ]*/
    
    // Specify preserve 30fps
    
    var pixelBufferAttributes: [String: Any]?
    
    init(fileType: AVFileType, videoSettings: [String: Any]?) {
        self.outputFileType = fileType
        self.videoSettings = videoSettings
        self.videoSettings?["AVVideoHeightKey"] = 480
        self.videoSettings?["AVVideoWidthKey"] = 640
        //print(self.videoSettings)
        self.pixelBufferAttributes = nil
    }
}
