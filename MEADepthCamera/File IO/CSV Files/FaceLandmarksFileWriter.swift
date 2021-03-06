//
//  FaceLandmarksFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/16/21.
//

import AVFoundation
import Vision
import OSLog

/// Writes face landmark position data from a recording to a CSV file.
class FaceLandmarksFileWriter: CSVFileWriter {
    
    enum Columns: String, CaseIterable {
        case frame
        case timeStamp
        case boundingBoxOriginX
        case boundingBoxOriginY
        case boundingBoxWidth
        case boundingBoxHeight
    }
    
    let outputType: OutputType
    
    let fileURL: URL
    
    /// String containing appropriate column labels for the CSV file, with commas as a delimiter.
    private var columnLabels: String {
        var columnLabels = Columns.allCases.map { $0.rawValue }.joined(separator: ",")
        for i in 0..<numLandmarks {
            columnLabels.append(",landmark_\(i)_x,landmark_\(i)_y,landmark_\(i)_z")
        }
        columnLabels.append("\n")
        return columnLabels
    }
    
    private let numLandmarks: Int
    
    private let logger = Logger.Category.fileIO.logger
    
    init?(recording: Recording, outputType: OutputType) {
        guard let numLandmarks = recording.processorSettings?.numLandmarks,
              let folderURL = recording.folderURL else { return nil }
        self.numLandmarks = numLandmarks
        self.outputType = outputType
        self.fileURL = Self.createFileURL(in: folderURL, outputType: outputType)
        writeColumnLabels(columnLabels)
    }
    
    // MARK: Write Row Data
    
    func writeRowData(frame: Int, timeStamp: Float64, boundingBox: CGRect, landmarks: [vector_float3]) {
        
        let formattedTimeStamp = String(format: "%.5f", timeStamp)
        
        // Create string to hold the row's data
        var data = "\(frame),\(formattedTimeStamp),"
        
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
            logger.error("\(self.typeName): Failed to convert data from type String to type Data.")
            return
        }
        // Write data to file
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(dataBuffer)
        } else {
            logger.error("\(self.typeName): Failed to write data to file.")
        }
    }
}
