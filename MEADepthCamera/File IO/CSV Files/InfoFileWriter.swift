//
//  InfoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 8/9/21.
//

import Foundation
import OSLog

/// Writes information about a recording to a CSV file.
class InfoFileWriter: CSVFileWriter {
    
    enum Columns: String, CaseIterable {
        case subjectID = "Subject_ID"
        case taskName = "Task"
        case startTime = "Start_Time"
        case landmarksCount = "Number_of_Landmarks"
        case videoWidth = "Video_Width"
        case videoHeight = "Video_Height"
        case depthMapWidth = "DepthMap_Width"
        case depthMapHeight = "DepthMap_Height"
        case totalFrames = "Total_Frames"
    }
    
    let outputType: OutputType = .info
    
    let fileURL: URL
    
    /// String containing appropriate column labels for the CSV file, with commas as a delimiter.
    private var columnLabels: String {
        Columns.allCases.map { $0.rawValue }.joined(separator: ",").appending("\n")
    }
    
    private let recording: Recording
    private let processorSettings: ProcessorSettings
    private let subjectID: String
    private let taskName: String
    
    let logger = Logger.Category.fileIO.logger
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss.SSS"
        return formatter
    }()
    
    init?(recording: Recording) {
        guard let processorSettings = recording.processorSettings,
              let folderURL = recording.folderURL,
              let subjectID = recording.useCase?.subjectID,
              let taskName = recording.task?.name else { return nil }
        self.recording = recording
        self.processorSettings = processorSettings
        self.subjectID = subjectID
        self.taskName = taskName
        self.fileURL = Self.createFileURL(in: folderURL, outputType: outputType)
        writeColumnLabels(columnLabels)
    }
    
    // MARK: Write Info Row
    
    func writeInfoRow(startTime: Date, totalFrames: Int) {
        
        let (portraitVideoResolution, portraitDepthResolution) = processorSettings.getPortraitResolutions()
        let startTimeString = dateFormatter.string(from: startTime)
        
        // Create string to hold the row's data.
        let data = "\(subjectID),\(taskName),\(startTimeString),\(processorSettings.numLandmarks),\(portraitVideoResolution.width),\(portraitVideoResolution.height),\(portraitDepthResolution.width),\(portraitDepthResolution.height),\(totalFrames),\n"
        
        // Convert string to data buffer.
        guard let dataBuffer = data.data(using: String.Encoding.utf8) else {
            logger.error("\(self.typeName): Failed to convert data from type String to type Data.")
            return
        }
        // Write data to file.
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
