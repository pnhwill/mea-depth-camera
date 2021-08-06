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
    
    private var saveURL: URL?
    
    init(numLandmarks: Int) {
        self.numLandmarks = numLandmarks
    }
    
    // MARK: Setup
    
    func prepare(saveURL: URL) {
        // Create and write column labels
        createLabels(fileURL: saveURL)
        self.saveURL = saveURL
    }
    
    func reset() {
        saveURL = nil
    }
    
//    private func createInfoRow() {
//
//    }
    
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
    
    // MARK: Write Row Data
    
    func writeToCSV(frame: Int, timeStamp: Float64, boundingBox: CGRect, landmarks: [vector_float3]) {
        guard let path = saveURL else {
            print("No save path found")
            return
        }
        
        // Create string to hold the row's data
        var data = "\(frame),\(timeStamp),"
        
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
    }
    
}
