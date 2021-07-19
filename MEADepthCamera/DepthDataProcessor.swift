//
//  DepthDataProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/16/21.
//

import AVFoundation
import Vision

class DepthDataProcessor {
    
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


// The following code is not implemented due to performance issues. It should be refactored into Metal shaders
/*
extension DepthDataProcessor {
    
    private func getLensDistortion(scaleX: CGFloat, scaleY: CGFloat) -> (CGPoint, [Float]) {
        // temporary method for lens distortion code
        
        // Get the distortion lookup table and center
        let distortionLookupTable = depthData?.cameraCalibrationData?.inverseLensDistortionLookupTable
        let distortionCenter = depthData?.cameraCalibrationData?.lensDistortionCenter
        // Scale the optical center to the depth map size
        let scaledDistortionCenter = CGPoint(x: distortionCenter!.x * CGFloat(scaleX), y: distortionCenter!.y * CGFloat(scaleY))
        
        // Convert lookup table to array
        // NOTE: it is bad for performance to convert the entire table to an array at each frame like this
        let lookupTableValues = distortionLookupTable!.toArray(type: Float.self)
        
        return (scaledDistortionCenter, lookupTableValues)
    }
    
    private func rectifyDepthDataMap(depthData: AVDepthData?) -> CVPixelBuffer? {
        // Method to rectify the depth data map from lens-distorted to rectilinear coordinate space
        guard let depthDataMap = depthData?.depthDataMap, let depthDataType = depthData?.depthDataType else {
            print("Depth data not found.")
            return nil
        }
        // Get the distortion lookup table and center
        guard
            let distortionLookupTable = depthData?.cameraCalibrationData?.inverseLensDistortionLookupTable,
            let distortionCenter = depthData?.cameraCalibrationData?.lensDistortionCenter else {
            return nil
        }
        
        // Convert lookup table to array
        // NOTE: it is bad for performance to convert the entire table to an array at each frame like this
        let lookupTableValues = distortionLookupTable.toArray(type: Float.self)
        
        // Get video and depth stream resolutions to convert between coordinate systems
        let depthMapWidth = CVPixelBufferGetWidth(depthDataMap)
        let depthMapHeight = CVPixelBufferGetHeight(depthDataMap)
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        let imageSize = self.captureDeviceResolution
        let scaleX = CGFloat(depthMapWidth) / CGFloat(imageSize.width)
        let scaleY = CGFloat(depthMapHeight) / CGFloat(imageSize.height)
        
        // Scale the optical center to the depth map size
        let scaledDistortionCenter = CGPoint(x: distortionCenter.x * scaleX, y: distortionCenter.y * scaleY)
        
        var outputBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(nil, depthMapWidth, depthMapHeight, depthDataType, nil, &outputBuffer)
        //print(result)
        
        if result == kCVReturnSuccess && outputBuffer != nil {
            CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
            CVPixelBufferLockBaseAddress(outputBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            
            let inputBytesPerRow = CVPixelBufferGetBytesPerRow(depthDataMap)
            guard let inputBaseAddress = CVPixelBufferGetBaseAddress(depthDataMap) else {
                return nil
            }
            let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer!)
            guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer!) else {
                return nil
            }
            
            // Loop over all output pixels
            for y in 0..<depthMapHeight {
                // Create pointer to output buffer
                let outputRowData = outputBaseAddress + y * outputBytesPerRow
                let outputData = UnsafeMutableBufferPointer(start: outputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
                
                for x in 0..<depthMapWidth {
                    // For each output pixel, do inverse distortion transformation and clamp the points within the bounds of the buffer
                    let distortedPoint = CGPoint(x: x, y: y)
                    var correctedPoint = lensDistortionPoint(for: distortedPoint, lookupTable: lookupTableValues, distortionOpticalCenter: scaledDistortionCenter, imageSize: depthMapSize)
                    correctedPoint.clamp(bounds: depthMapSize)
                    
                    // Create pointer to input buffer
                    let inputRowData = inputBaseAddress + Int(correctedPoint.y) * inputBytesPerRow
                    let inputData = UnsafeBufferPointer(start: inputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
                    
                    // Sample pixel value from input buffer and pull into output buffer
                    let pixelValue = inputData[Int(correctedPoint.x)]
                    outputData[x] = pixelValue
                }
            }
            CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(outputBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        } else {
            print("Failed to create output pixel buffer.")
            return nil
        }
        
        return outputBuffer
    }
    
    private func lensDistortionPoint(for point: CGPoint, lookupTable: [Float], distortionOpticalCenter opticalCenter: CGPoint, imageSize: CGSize) -> CGPoint {
        // The lookup table holds the relative radial magnification for n linearly spaced radii.
        // The first position corresponds to radius = 0
        // The last position corresponds to the largest radius found in the image.
        
        // Determine the maximum radius.
        let delta_ocx_max = Float(max(opticalCenter.x, imageSize.width  - opticalCenter.x))
        let delta_ocy_max = Float(max(opticalCenter.y, imageSize.height - opticalCenter.y))
        let r_max = sqrt(delta_ocx_max * delta_ocx_max + delta_ocy_max * delta_ocy_max)
        
        // Determine the vector from the optical center to the given point.
        let v_point_x = Float(point.x - opticalCenter.x)
        let v_point_y = Float(point.y - opticalCenter.y)
        
        // Determine the radius of the given point.
        let r_point = sqrt(v_point_x * v_point_x + v_point_y * v_point_y)
        
        // Look up the relative radial magnification to apply in the provided lookup table
        
        let magnification: Float
        //let lookupTableValues = lookupTable.toArray(type: Float.self)
        if r_point < r_max {
            // Linear interpolation
            let val   = r_point / r_max
            let idx   = Int(val)
            let frac  = val - Float(idx)
            
            let mag_1 = lookupTable[idx]
            let mag_2 = lookupTable[idx + 1]
            
            magnification = (1.0 - frac) * mag_1 + frac * mag_2
        } else {
            magnification = lookupTable.last!
        }
        
        // Deprecated implementation below, which pulls lookup table values straight from the source data.
        // NOTE: this is faster than my implementation, but I'm not sure how to update this yet.
        /*
         let magnification: Float = lookupTable.withUnsafeBytes { (lookupTableValues: UnsafePointer<Float>) in
         let lookupTableCount = lookupTable.count / MemoryLayout<Float>.size
         
         if r_point < r_max {
         // Linear interpolation
         let val   = r_point * Float(lookupTableCount - 1) / r_max
         let idx   = Int(val)
         let frac  = val - Float(idx)
         
         let mag_1 = lookupTableValues[idx]
         let mag_2 = lookupTableValues[idx + 1]
         
         return (1.0 - frac) * mag_1 + frac * mag_2
         } else {
         return lookupTableValues[lookupTableCount - 1]
         }
         }
         */
        
        // Apply radial magnification
        let new_v_point_x = v_point_x + magnification * v_point_x
        let new_v_point_y = v_point_y + magnification * v_point_y
        
        // Construct output
        return CGPoint(x: opticalCenter.x + CGFloat(new_v_point_x), y: opticalCenter.y + CGFloat(new_v_point_y))
    }
}

extension Data {
    // Method to convert from data to array
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}

extension CGPoint {
    // Method to clamp a CGPoint within a certain bounds
    mutating func clamp(bounds: CGSize) {
        self.x = min(bounds.width, max(self.x, 0.0))
        self.y = min(bounds.height, max(self.y, 0.0))
    }
}
*/
