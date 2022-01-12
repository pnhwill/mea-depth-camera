//
//  FaceAlignment.swift
//  MEADepthCamera
//
//  Created by Will on 12/8/21.
//

import Vision

/// Encapsulation of necessary conditions for correct face alignment in the captured image.
/// Automatically calculates if the detected face is centered on and facing towards the camera using SIMD operations.
///
/// Note that the  `boundingBox` property of `VNFaceObservation` is normalized to the dimensions of
/// the processed image, with the origin at the lower-left corner of the image.
struct FaceAlignment {
    
    typealias Position = SIMD2<Float>
    typealias Size = SIMD2<Float>
    typealias Rotation = SIMD3<Float>
    
    static let alignedPosition = Position(0.5, 0.43)
    static let alignedSize = Size(0.45, 0.25)
    
    static let positionMargin: Float = pow(0.1, 2)
    static let sizeMargin: Float = pow(0.15, 2)
    static let rotationMargin = Rotation(repeating: degreesToRadians(10))
    
    let position: Position
    let size: Size
    let rotation: Rotation
    
    var isAligned: Bool { positionCondition && sizeCondition && rotationCondition }
    
    private var positionError: Float { distance_squared(position, Self.alignedPosition) }
    private var sizeError: Float { distance_squared(size, Self.alignedSize) }
    private var rotationError: Rotation { abs(rotation) }
    
    private var positionCondition: Bool { positionError < Self.positionMargin }
    private var sizeCondition: Bool { sizeError < Self.sizeMargin }
    private var rotationCondition: Bool { all(rotationError .< Self.rotationMargin) }
    
    init(faceObservation: VNFaceObservation) {
        let boundingBox = faceObservation.boundingBox
        self.position = Position(boundingBox.midpoint)
        self.size = Size(boundingBox.size)
        self.rotation = Rotation(faceObservation.roll ?? 0,
                                 faceObservation.yaw ?? 0,
                                 faceObservation.pitch ?? 0)
    }
}
