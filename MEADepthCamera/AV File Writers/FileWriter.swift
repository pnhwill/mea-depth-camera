//
//  FileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation
import Combine

// This implements a protocol for all AV file writers

protocol FileWriter: AnyObject {
    
    associatedtype OutputSettings: FileConfiguration
    associatedtype S: Subject
    
    var assetWriter: AVAssetWriter { get }
    
    var writeState: WriteState { get set }
    
    var done: AnyCancellable? { get set }
    var subject: S { get }
    
    init(outputURL: URL, configuration: OutputSettings, subject: S) throws
    
    func start(at startTime: CMTime)
    
    func finish(completion: Subscribers.Completion<Error>)
    
}
