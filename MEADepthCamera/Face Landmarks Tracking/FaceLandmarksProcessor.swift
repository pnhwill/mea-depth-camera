//
//  FaceLandmarksProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision

class FaceLandmarksProcessor {
    
    let numLandmarks: Int = 76
    
    //var depthData: AVDepthData?
    
    var captureDeviceResolution: CGSize
    
    init(resolution: CGSize) {
        captureDeviceResolution = resolution
    }
    
    //var lookupTable: [Float]?
    
    // MARK: - Methods to get depth data for landmarks
    
    func calculatePointCloud(faceObservation: VNFaceObservation, depthData: AVDepthData) -> Array<Float> {
        // This method calculates the physical point cloud locations of all landmarks.
        
        // Get camera instrinsics and depth map pixel buffer
        guard let intrinsicMatrix = depthData.cameraCalibrationData?.intrinsicMatrix,
              // NOTE: we use getDepthData instead of rectifyDepthData here because it's too laggy to be useful and also doesn't seem to work correctly
              let depthDataMap = getDepthDataMap(depthData: depthData) else {
            print("Failed to obtain camera data or depth map.")
            return []
        }
        
        // Get video and depth stream resolutions to convert between coordinate systems
        let depthMapWidth = CVPixelBufferGetWidth(depthDataMap)
        let depthMapHeight = CVPixelBufferGetHeight(depthDataMap)
        //let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        let imageSize = self.captureDeviceResolution
        
        let scaleX = Float(depthMapWidth) / Float(imageSize.width)
        let scaleY = Float(depthMapHeight) / Float(imageSize.height)
        
        // Bring focal and principal points into the same coordinate system as the depth map
        let focalX = intrinsicMatrix[0][0] * scaleX
        let focalY = intrinsicMatrix[1][1] * scaleY
        let principalPointX = intrinsicMatrix[2][0] * scaleX
        let principalPointY = intrinsicMatrix[2][1] * scaleY
        
        var landmarkDepths = Array(repeating: Float(0.0), count: numLandmarks * 3)
        
        // Lock pixel buffer for accessing pixel data
        CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthDataMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthDataMap) else {
            return []
        }
        
        // Get face bounding box and landmarks
        let boundingBox = faceObservation.boundingBox
        if let landmarks = faceObservation.landmarks?.allPoints {
            for (i, landmark) in landmarks.normalizedPoints.enumerated() {
                let landmarkVector: simd_float2 = simd_float2(Float(landmark.x), Float(landmark.y))
                // Get the pixel coordinate in depth map image size (640x480)
                let landmarkPixel = VNImagePointForFaceLandmarkPoint(landmarkVector, boundingBox, Int(depthMapWidth), Int(depthMapHeight))
                //let correctedLandmarkPixel = lensDistortionPoint(for: landmarkPixel, lookupTable: lookupTableValues, distortionOpticalCenter: scaledDistortionCenter, imageSize: depthMapSize)
                
                // Get depth value at memory address of the pixel nearest to the landmark in the depth map pixel buffer
                let rowData = baseAddress + Int(landmarkPixel.y) * bytesPerRow
                let depth = rowData.assumingMemoryBound(to: Float32.self)[Int(landmarkPixel.x)]
                
                // Calculate the absolute physical location of the landmark
                // Apple says to do this with Metal shaders, but since we're only finding 76 points (rather than an entire image) it's fine to compute on the CPU
                let X = (Float(landmarkPixel.x) - principalPointX) * depth / focalX
                let Y = (Float(landmarkPixel.y) - principalPointY) * depth / focalY
                
                landmarkDepths[3*i] = X
                landmarkDepths[3*i + 1] = Y
                landmarkDepths[3*i + 2] = depth
            }
        } else {
            print("Invalid face detection request.")
        }
        CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
        
        return landmarkDepths
    }
    
    private func getDepthDataMap(depthData: AVDepthData?) -> CVPixelBuffer? {
        // Debugging method that returns uncorrected depth map
        guard let depthDataMap = depthData?.depthDataMap else {
            print("Depth data not found.")
            return nil
        }
        return depthDataMap
    }
    
    
    
}
