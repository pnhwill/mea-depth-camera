//
//  FaceLandmarksProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision

class FaceLandmarksProcessor {
    
    private var numLandmarks: Int
    private var videoResolution: CGSize
    private var depthResolution: CGSize
    
    // Point cloud Metal renderer with compute kernel
    private var pointCloudProcessor: PointCloudProcessor
    
    init(videoResolution: CGSize, depthResolution: CGSize, numLandmarks: Int) {
        self.videoResolution = videoResolution
        self.depthResolution = depthResolution
        self.numLandmarks = numLandmarks
        self.pointCloudProcessor = PointCloudProcessor(numLandmarks: numLandmarks)
    }
    
    //var lookupTable: [Float]?
    
    // MARK: - Methods to get depth data for landmarks
    
    func processFace(_ faceObservation: VNFaceObservation?, with depthData: AVDepthData?) -> (CGRect, [vector_float3]) {
        // This method combines a face observation and depth data to produce a bounding box and face landmarks in 3D space.
        // If no depth is provided, it returns the 2D landmarks in image coordinates.
        // If no landmarks are provided, it returns just the bounding box.
        // If no face observation is provided, it returns all zeros.
        
        // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later
        var boundingBox = CGRect.zero
        var landmarks3D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates
            boundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(videoResolution.width), Int(videoResolution.height))
            
            if let landmarks = faceObservation.landmarks?.allPoints {

                if let depthData = depthData {
                    
                    let landmarkPoints = landmarks.pointsInImage(imageSize: depthResolution)
                    let landmarkVectors = landmarkPoints.map { simd_float2(Float($0.x), Float($0.y)) }
                    
                    if !pointCloudProcessor.isPrepared {
                        var depthFormatDescription: CMFormatDescription?
                        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                     imageBuffer: depthData.depthDataMap,
                                                                     formatDescriptionOut: &depthFormatDescription)
                        if let unwrappedDepthFormatDescription = depthFormatDescription {
                            pointCloudProcessor.prepare(with: unwrappedDepthFormatDescription)
                        }
                    }
                    pointCloudProcessor.render(landmarks: landmarkVectors, depthData: depthData)
                    
                    for (index, _) in landmarks.normalizedPoints.enumerated() {
                        guard let landmarkPoint = pointCloudProcessor.getOutput(index: index) else {
                            // If any of the landmarks fails to be processed, it discards the rest and returns just as if no depth was given
                            print("Metal point cloud processor failed to output landmark position. Returning landmarks in RGB image coordinates.")
                            let landmarkPoints = landmarks.pointsInImage(imageSize: videoResolution)
                            landmarks3D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                            return (boundingBox, landmarks3D)
                        }
                        landmarks3D[index] = landmarkPoint
                    }
                } else {
                    print("No depth data found. Returning 2D landmarks in RGB image coordinates.")
                    let landmarkPoints = landmarks.pointsInImage(imageSize: videoResolution)
                    landmarks3D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                }
            } else {
                print("Invalid face detection request: no face landmarks. Returning bounding box only.")
            }
        } else {
            print("No face observation found. Inserting zeros for all values.")
        }
        return (boundingBox, landmarks3D)
    }
}
