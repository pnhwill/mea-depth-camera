//
//  ProcessorSettings.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import AVFoundation

public class ProcessorSettings: NSObject {
    
    // The number of landmarks depends on the Vision request revision
    var numLandmarks: Int = 76
    // These sizes represent the final output resolutions in portrait orientation
    var videoResolution: CGSize
    var depthResolution: CGSize
    // The video/depth frames are delivered in landscapeLeft orientation, so we need to know how to rotate their dimensions
    var videoOrientation: AVCaptureVideoOrientation
    // We have to wait until we receive the first depth frame to set the camera calibration data
    var cameraCalibrationData: AVCameraCalibrationData?
    var decodedCameraCalibrationData: CodingCameraCalibrationData?
    
    init(videoDimensions: CMVideoDimensions, depthDimensions: CMVideoDimensions, videoOrientation: AVCaptureVideoOrientation) {
        self.videoOrientation = videoOrientation
        self.videoResolution = CGSize(width: Int(videoDimensions.width), height: Int(videoDimensions.height))
        self.depthResolution = CGSize(width: Int(depthDimensions.width), height: Int(depthDimensions.height))
        super.init()
    }
    
    // Required initializer for NSSecureCoding
    public required init?(coder: NSCoder) {
        let numLandmarks = coder.decodeInteger(forKey: CodingKeys.numLandmarks.rawValue)
        let videoResolution = coder.decodeCGSize(forKey: CodingKeys.videoResolution.rawValue)
        let depthResolution = coder.decodeCGSize(forKey: CodingKeys.depthResolution.rawValue)
        guard let videoOrientation = AVCaptureVideoOrientation(rawValue: coder.decodeInteger(forKey: CodingKeys.videoOrientation.rawValue)) else { return nil }
        let cameraCalibrationData = coder.decodeObject(of: CodingCameraCalibrationData.self, forKey: CodingKeys.cameraCalibrationData.rawValue)
        
        self.numLandmarks = numLandmarks
        self.videoResolution = videoResolution
        self.depthResolution = depthResolution
        self.videoOrientation = videoOrientation
        self.decodedCameraCalibrationData = cameraCalibrationData
    }
}

// MARK: Convenience Getter Methods
extension ProcessorSettings {
    func getTransform() -> CGAffineTransform {
        // The TrueDepth camera is in the front position
        let angleOffset = CGFloat(videoOrientation.angleOffsetFromPortraitOrientation(at: .front))
        let transform = CGAffineTransform(rotationAngle: angleOffset)
        return transform
    }
    
    func getPortraitResolutions() -> (CGSize, CGSize) {
        let portraitVideoResolution = CGRect(x: 0, y: 0, width: CGFloat(videoResolution.width), height: CGFloat(videoResolution.height)).applying(getTransform()).standardized.size.rounded()
        let portraitDepthResolution = CGRect(x: 0, y: 0, width: CGFloat(depthResolution.width), height: CGFloat(depthResolution.height)).applying(getTransform()).standardized.size.rounded()
        return (portraitVideoResolution, portraitDepthResolution)
    }
}

// MARK: NSSecureCoding
extension ProcessorSettings: NSSecureCoding {
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    private enum CodingKeys: String, CodingKey {
        case numLandmarks
        case videoResolution
        case depthResolution
        case videoOrientation
        case cameraCalibrationData
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(numLandmarks, forKey: CodingKeys.numLandmarks.rawValue)
        coder.encode(videoResolution, forKey: CodingKeys.videoResolution.rawValue)
        coder.encode(depthResolution, forKey: CodingKeys.depthResolution.rawValue)
        coder.encode(videoOrientation.rawValue, forKey: CodingKeys.videoOrientation.rawValue)
        let codingCameraCalibrationData = CodingCameraCalibrationData(from: cameraCalibrationData!)
        coder.encode(codingCameraCalibrationData, forKey: CodingKeys.cameraCalibrationData.rawValue)
    }
}

// MARK: CodingCameraCalibrationData
class CodingCameraCalibrationData: NSObject, NSSecureCoding {
    // Helper class to encode/decode all the properties from AVCameraCalibrationData
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    private enum CodingKeys: String, CodingKey {
        case intrinsicMatrix
        case intrinsicMatrixReferenceDimensions
        case extrinsicMatrix
        case pixelSize
        case lensDistortionLookupTable
        case inverseLensDistortionLookupTable
        case lensDistortionCenter
    }
    
    var intrinsicMatrix: matrix_float3x3
    var intrinsicMatrixReferenceDimensions: CGSize
    var extrinsicMatrix: matrix_float4x3
    var pixelSize: Float
    var lensDistortionLookupTable: Data?
    var inverseLensDistortionLookupTable: Data?
    var lensDistortionCenter: CGPoint
    
    init(from cameraCalibrationData: AVCameraCalibrationData) {
        self.intrinsicMatrix = cameraCalibrationData.intrinsicMatrix
        self.intrinsicMatrixReferenceDimensions = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        self.extrinsicMatrix = cameraCalibrationData.extrinsicMatrix
        self.pixelSize = cameraCalibrationData.pixelSize
        self.lensDistortionLookupTable = cameraCalibrationData.lensDistortionLookupTable
        self.inverseLensDistortionLookupTable = cameraCalibrationData.inverseLensDistortionLookupTable
        self.lensDistortionCenter = cameraCalibrationData.lensDistortionCenter
    }
    
    required init?(coder: NSCoder) {
        guard let intrinsicMatrixObject = coder.decodeObject(of: CodingMatrixFloat3.self, forKey: CodingKeys.intrinsicMatrix.rawValue),
              !intrinsicMatrixObject.columns.isEmpty else { return nil }
        let intrinsicMatrix = matrix_float3x3(intrinsicMatrixObject.columns)
        let intrinsicMatrixReferenceDimensions = coder.decodeCGSize(forKey: CodingKeys.intrinsicMatrixReferenceDimensions.rawValue)
        guard let extrinsicMatrixObject = coder.decodeObject(of: CodingMatrixFloat3.self, forKey: CodingKeys.extrinsicMatrix.rawValue),
              !extrinsicMatrixObject.columns.isEmpty else { return nil }
        let extrinsicMatrix = matrix_float4x3(extrinsicMatrixObject.columns)
        let pixelSize = coder.decodeFloat(forKey: CodingKeys.pixelSize.rawValue)
        guard let lensDistortionLookupTable = coder.decodeObject(of: NSData.self, forKey: CodingKeys.lensDistortionLookupTable.rawValue) as Data?,
              let inverseLensDistortionLookupTable = coder.decodeObject(of: NSData.self, forKey: CodingKeys.inverseLensDistortionLookupTable.rawValue) as Data? else { return nil }
        let lensDistortionCenter = coder.decodeCGPoint(forKey: CodingKeys.lensDistortionCenter.rawValue)
        
        self.intrinsicMatrix = intrinsicMatrix
        self.intrinsicMatrixReferenceDimensions = intrinsicMatrixReferenceDimensions
        self.extrinsicMatrix = extrinsicMatrix
        self.pixelSize = pixelSize
        self.lensDistortionLookupTable = lensDistortionLookupTable
        self.inverseLensDistortionLookupTable = inverseLensDistortionLookupTable
        self.lensDistortionCenter = lensDistortionCenter
    }
    
    func encode(with coder: NSCoder) {
        let intrinsicMatrixObject = CodingMatrixFloat3([intrinsicMatrix.columns.0, intrinsicMatrix.columns.1, intrinsicMatrix.columns.2])
        coder.encode(intrinsicMatrixObject, forKey: CodingKeys.intrinsicMatrix.rawValue)
        coder.encode(intrinsicMatrixReferenceDimensions, forKey: CodingKeys.intrinsicMatrixReferenceDimensions.rawValue)
        let extrinsicMatrixObject = CodingMatrixFloat3([extrinsicMatrix.columns.0, extrinsicMatrix.columns.1, extrinsicMatrix.columns.2, extrinsicMatrix.columns.3])
        coder.encode(extrinsicMatrixObject, forKey: CodingKeys.extrinsicMatrix.rawValue)
        coder.encode(pixelSize, forKey: CodingKeys.pixelSize.rawValue)
        coder.encode(lensDistortionLookupTable, forKey: CodingKeys.lensDistortionLookupTable.rawValue)
        coder.encode(inverseLensDistortionLookupTable, forKey: CodingKeys.inverseLensDistortionLookupTable.rawValue)
        coder.encode(lensDistortionCenter, forKey: CodingKeys.lensDistortionCenter.rawValue)
    }
    
}

// MARK: CodingMatrixFloat3
class CodingMatrixFloat3: NSObject, NSSecureCoding {
    // Helper class which can encode/decode any size SIMD matrix type with SIMD3 column vectors
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    typealias Float3 = SIMD3<Float>
    
    private enum CodingKeys: String, CodingKey {
        case columns
    }
    
    var columns: [Float3] = []
    
    init(_ columns: [Float3]) {
        self.columns = columns
    }
    
    required init?(coder: NSCoder) {
        super.init()
        // decodeBytesForKey() returns an UnsafePointer<UInt8>?, pointing to immutable data.
        var length = 0
        if let bytePointer = coder.decodeBytes(forKey: CodingKeys.columns.rawValue, returnedLength: &length) {
            // Convert it to a buffer pointer of the appropriate type and count and create the array.
            let numColumns = length / MemoryLayout<Float3>.stride
            bytePointer.withMemoryRebound(to: Float3.self, capacity: numColumns) { pointer in
                let bufferPointer = UnsafeBufferPointer<Float3>(start: pointer, count: numColumns)
                self.columns = Array<Float3>(bufferPointer)
                print("Finished decoding matrix float3")
            }
        }
    }
    
    func encode(with coder: NSCoder) {
        // This encodes both the number of bytes and the data itself.
        let numBytes = columns.count * MemoryLayout<Float3>.stride
        columns.withUnsafeBufferPointer { bufferPointer in
            bufferPointer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: numBytes) { pointer in
                coder.encodeBytes(pointer, length: numBytes, forKey: CodingKeys.columns.rawValue)
                print("Finished encoding matrix float3")
            }
        }
    }
}
