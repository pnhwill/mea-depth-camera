//
//  VideoReader.swift
//  MEADepthCamera
//
//  Created by Will on 8/2/21.
//

import AVFoundation
import OSLog

/// Contains the video reader implementation using AVFoundation.
class VideoReader {
    static private let millisecondsInSecond: Float32 = 1000.0
    
    var frameRateInMilliseconds: Float32 {
        return self.videoTrack.nominalFrameRate
    }

    var frameRateInSeconds: Float32 {
        return self.frameRateInMilliseconds * VideoReader.millisecondsInSecond
    }

    var affineTransform: CGAffineTransform {
        return self.videoTrack.preferredTransform.inverted()
    }
    
    var orientation: CGImagePropertyOrientation {
        let angleInDegrees = atan2(self.affineTransform.b, self.affineTransform.a) * CGFloat(180) / CGFloat.pi
        
        var orientation: UInt32 = 1
        switch angleInDegrees {
        case 0:
            orientation = 1 // Recording button is on the right
        case 180:
            orientation = 3 // abs(180) degree rotation recording button is on the right
        case -180:
            orientation = 3 // abs(180) degree rotation recording button is on the right
        case 90:
            orientation = 8 // 90 degree CW rotation recording button is on the top
        case -90:
            orientation = 6 // 90 degree CCW rotation recording button is on the bottom
        default:
            orientation = 1
        }
        
        return CGImagePropertyOrientation(rawValue: orientation)!
    }
    
    private var videoDataType: OutputType
    private var outputSettings: [String: Any] {
        switch videoDataType {
        case .depth:
            return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        default:
            return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        }
    }
    
    private var videoAsset: AVAsset!
    private var videoTrack: AVAssetTrack!
    private var assetReader: AVAssetReader!
    private var videoAssetReaderOutput: AVAssetReaderTrackOutput!

    init?(videoAsset: AVAsset, videoDataType: OutputType) {
        self.videoAsset = videoAsset
        let array = self.videoAsset.tracks(withMediaType: AVMediaType.video)
        self.videoTrack = array[0]
        self.videoDataType = videoDataType
        guard self.restartReading() else {
            return nil
        }
    }

    func restartReading() -> Bool {
        do {
            self.assetReader = try AVAssetReader(asset: videoAsset)
        } catch {
            Logger.Category.fileIO.logger.error("Failed to create AVAssetReader object: \(String(describing: error))")
            return false
        }
        
        self.videoAssetReaderOutput = AVAssetReaderTrackOutput(track: self.videoTrack, outputSettings: self.outputSettings)
        guard self.videoAssetReaderOutput != nil else {
            return false
        }
        
        self.videoAssetReaderOutput.alwaysCopiesSampleData = true

        guard self.assetReader.canAdd(videoAssetReaderOutput) else {
            return false
        }
        
        self.assetReader.add(videoAssetReaderOutput)
        
        return self.assetReader.startReading()
    }

    func nextFrame() -> CMSampleBuffer? {
        guard let sampleBuffer = self.videoAssetReaderOutput.copyNextSampleBuffer() else {
            return nil
        }
        
        return sampleBuffer
    }
}
