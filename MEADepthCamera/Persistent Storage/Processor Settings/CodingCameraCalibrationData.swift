//
//  CodingCameraCalibrationData.swift
//  MEADepthCamera
//
//  Created by Will on 10/13/21.
//

import AVFoundation

protocol CameraCalibrationDataProtocol {
    var intrinsicMatrix: matrix_float3x3 { get }
    var intrinsicMatrixReferenceDimensions: CGSize { get }
    var extrinsicMatrix: matrix_float4x3 { get }
    var pixelSize: Float { get }
    var lensDistortionLookupTable: Data? { get }
    var inverseLensDistortionLookupTable: Data? { get }
    var lensDistortionCenter: CGPoint { get }
}

extension AVCameraCalibrationData: CameraCalibrationDataProtocol {
}

// MARK: CodingCameraCalibrationData
class CodingCameraCalibrationData: NSObject, NSSecureCoding, CameraCalibrationDataProtocol {
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
