//
//  FileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation

// This implements a protocol and helper objects for all AV file writers

enum FileWriteResult {
    case success
    case failed(Error?)
}

protocol FileWriter: AnyObject {
    
    var assetWriter: AVAssetWriter { get }
    
    associatedtype OutputSettings: FileConfiguration
    
    init(outputURL: URL, configuration: OutputSettings) throws
    
    func start(at startTime: CMTime)
    
    func finish(at endTime: CMTime, _ completion: @escaping (FileWriteResult) -> Void)
    
}
