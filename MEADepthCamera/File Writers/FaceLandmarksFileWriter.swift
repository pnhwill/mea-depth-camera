//
//  FaceLandmarksFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/16/21.
//

import AVFoundation
import Vision

class FaceLandmarksFileWriter: FileWriter {
    
    private var numLandmarks: Int
    
    private var savePath: URL?
    private var startTime: Date?
    private var frameCount: Int = 0
    
    init(numLandmarks: Int) {
        self.numLandmarks = numLandmarks
    }
    
    func startDataCollection(path: URL) {
        // Create and write column labels
        createLabels(fileURL: path)
        self.savePath = path
        self.startTime = Date()
        self.frameCount = 0
    }
    
    private func createInfoRow() {
        
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
    
    func writeToCSV(boundingBox: CGRect, landmarks: [vector_float3]) {
        guard let path = savePath, let start = startTime else {
            print("No save path found")
            return
        }
        
        // Get timestamp and frame to record
        let date = Date()
        let timeStamp = date.timeIntervalSince(start)
        
        // Create string to hold the row's data
        var data = "\(frameCount),\(timeStamp),"
        
        // Add face bounding box in RGB image coordinates to string
        data.append("\(boundingBox.origin.x),\(boundingBox.origin.y),\(boundingBox.size.width),\(boundingBox.size.height),")
        
        for landmark in landmarks {
            let landmarkX = landmark.x
            let landmarkY = landmark.y
            let landmarkZ = landmark.z
            data.append("\(landmarkX),\(landmarkY),\(landmarkZ),")
        }
        data.append("\n")
        
        // Convert string to data buffer
        guard let dataBuffer = data.data(using: String.Encoding.utf8) else {
            print("Failed to convert data from type String to type Data.")
            return
        }
        // Write data to file
        if let fileHandle = try? FileHandle(forWritingTo: path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(dataBuffer)
        } else {
            print("Failed to write data to file.")
        }
        // Update the frame count
        frameCount += 1
    }
    
    func reset() {
        savePath = nil
        startTime = nil
    }
}
