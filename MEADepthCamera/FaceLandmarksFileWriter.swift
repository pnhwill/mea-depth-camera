//
//  FaceLandmarksFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/16/21.
//

import AVFoundation
import Vision

class FaceLandmarksFileWriter {
    
    let numLandmarks: Int = 76
    
    struct DataCollector {
        // Simple type to keep track of current file path, initial time, and frame while recording
        let savePath: URL
        let startTime: Date
        var frameCount: Int
        
        init(path: URL) {
            self.savePath = path
            self.startTime = Date()
            self.frameCount = 0
        }
    }
    
    var dataCollector: DataCollector?
    
    var captureDeviceResolution: CGSize = CGSize()
    
    var depthDataProcessor: DepthDataProcessor
    
    // Temporary variable for testing
    private var metalRenderEnabled: Bool = false
    // Point cloud Metal renderer
    private var pointCloudMetalRenderer = PointCloudMetalRenderer()
    
    init(resolution: CGSize) {
        captureDeviceResolution = resolution
        depthDataProcessor = DepthDataProcessor(resolution: resolution)
    }
    
    func startDataCollection(path: URL) {
        // Create and write column labels
        createLabels(fileURL: path)
        // Instantiate a new DataCollector object
        dataCollector = DataCollector(path: path)
    }
    
    private func createLabels(fileURL: URL) {
        // Create string with appropriate column labels
        var columnLabels = "Frame,Timestamp(s),BBox_x,BBox_y,BBox_width,BBox_height,"
        for i in 0..<numLandmarks {
            columnLabels.append("landmark_\(i)_x,landmark_\(i)_y,landmark_\(i)_z,")
        }
        columnLabels.append("\n")
        // Write columns labels to first row in file
        do {
            try columnLabels.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Failed to write to file: \(error)")
        }
    }
    
    func writeToCSV(faceObservation: VNFaceObservation?, depthData: AVDepthData) {
        guard let dataCollector = self.dataCollector else {
            print("No save path found.")
            return
        }
        
        // Get timestamp and frame to record
        let date = Date()
        let timeStamp = date.timeIntervalSince(dataCollector.startTime)
        let frame = dataCollector.frameCount
        
        let imageSize = self.captureDeviceResolution
        
        // Create string to hold the row's data
        var data = "\(frame),\(timeStamp),"
        
        if faceObservation != nil {
            // Get face bounding box in image coordinates and add to string
            let boundingBox = VNImageRectForNormalizedRect(faceObservation!.boundingBox, Int(imageSize.width), Int(imageSize.height))
            data.append("\(boundingBox.origin.x),\(boundingBox.origin.y),\(boundingBox.size.width),\(boundingBox.size.height),")
            
            if metalRenderEnabled {
                
                guard let landmarksPointer = metalRender(faceObservation: faceObservation!, depthData: depthData) else {
                    print("metal rendering failed")
                    return
                }
                if let landmarks = faceObservation!.landmarks?.allPoints {
                    for (index, _) in landmarks.normalizedPoints.enumerated() {
                        let landmarkX = landmarksPointer[index].x
                        let landmarkY = landmarksPointer[index].y
                        let landmarkZ = landmarksPointer[index].z
                        data.append("\(landmarkX),\(landmarkY),\(landmarkZ),")
                    }
                } else {
                    print("Invalid face detection request.")
                }
                
            } else {
                // Get all face landmarks and add point cloud locations to string
                let landmarkPoints = depthDataProcessor.calculatePointCloud(faceObservation: faceObservation!, depthData: depthData)
                if let landmarks = faceObservation!.landmarks?.allPoints {
                    for (index, _) in landmarks.normalizedPoints.enumerated() {
                        let landmarkX = landmarkPoints[3*index]
                        let landmarkY = landmarkPoints[3*index + 1]
                        let landmarkZ = landmarkPoints[3*index + 2]
                        data.append("\(landmarkX),\(landmarkY),\(landmarkZ),")
                    }
                } else {
                    print("Invalid face detection request.")
                }
            }
            
        } else {
            // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later
            print("No face observation found. Inserting zeros for all values.")
            let numColumns = numLandmarks * 3 + 4
            for _ in 0..<numColumns {
                data.append("\(0.0),")
            }
        }
        data.append("\n")
        // Convert string to data buffer
        guard let dataBuffer = data.data(using: String.Encoding.utf8) else {
            print("Failed to convert data from type String to type Data.")
            return
        }
        // Write data to file
        let path = dataCollector.savePath
        if let fileHandle = try? FileHandle(forWritingTo: path as URL) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(dataBuffer)
        } else {
            print("Failed to write data to file.")
        }
        // Update the frame count
        self.dataCollector!.frameCount += 1
    }
    
    private func metalRender(faceObservation: VNFaceObservation, depthData: AVDepthData) -> UnsafeMutablePointer<vector_float3>? {
        // Get depth map pixel buffer
        let depthDataMap = depthData.depthDataMap
        
        // Get video and depth stream resolutions to convert between coordinate systems
        let depthMapWidth = CVPixelBufferGetWidth(depthDataMap)
        let depthMapHeight = CVPixelBufferGetHeight(depthDataMap)
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        
        // Declare output array of 3D points
        var landmarksPointCloud: [vector_float3]
        
        // Get face landmarks
        guard let landmarks = faceObservation.landmarks?.allPoints else {
            print("No landmarks found.")
            return nil
        }
        let landmarkPoints = landmarks.pointsInImage(imageSize: depthMapSize)
        let landmarkVectors = landmarkPoints.map { simd_float2(Float($0.x), Float($0.y)) }
        
        pointCloudMetalRenderer.setDepthFrame(depthData, withLandmarks: landmarkVectors)
        
        let outputPointer: UnsafeMutablePointer<vector_float3> = pointCloudMetalRenderer.getOutput()
        
        return outputPointer
    }
    
    
    
    
    
}
