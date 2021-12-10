//
//  InfoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 8/9/21.
//

import Foundation

/// Writes information about a recording to a CSV file.
class InfoFileWriter: CSVFileWriter {
    
    let outputType: OutputType = .info
    
    let fileURL: URL
    
    /// String containing appropriate column labels for the CSV file, with commas as a delimiter.
    private var columnLabels: String {
        "Patient_ID,Task,Start_Time,Number_of_Landmarks,Video_Width,Video_Height,DepthMap_Width,DepthMap_Height,Total_Frames,\n"
    }
    
    private let recording: Recording
    private let processorSettings: ProcessorSettings
    private let subjectID: String
    private let taskName: String
    
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
    
    func writeInfoRow(startTime: String, totalFrames: Int) {
        
        let (portraitVideoResolution, portraitDepthResolution) = processorSettings.getPortraitResolutions()
        
        // Create string to hold the row's data.
        let data = "\(subjectID),\(taskName),\(startTime),\(processorSettings.numLandmarks),\(portraitVideoResolution.width),\(portraitVideoResolution.height),\(portraitDepthResolution.width),\(portraitDepthResolution.height),\(totalFrames),\n"
        
        // Convert string to data buffer.
        guard let dataBuffer = data.data(using: String.Encoding.utf8) else {
            print("Failed to convert data from type String to type Data.")
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
            print("Failed to write data to file.")
        }
    }
}
