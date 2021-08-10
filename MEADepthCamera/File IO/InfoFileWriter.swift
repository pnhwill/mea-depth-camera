//
//  InfoFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 8/9/21.
//

import Foundation

class InfoFileWriter: CSVFileWriter {
    
    private var processorSettings: ProcessorSettings
    
    private var saveURL: URL?
    
    init(processorSettings: ProcessorSettings) {
        self.processorSettings = processorSettings
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
    
    private func createLabels(fileURL: URL) {
        // Create string with appropriate column labels
        let columnLabels = "Patient_ID,Task,Start_Time,Number_of_Landmarks,Video_Width,Video_Height,DepthMap_Width,DepthMap_Height,Total_Frames,\n"
        // Write columns labels to first row in file
        do {
            try columnLabels.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Failed to write to file: \(error)")
        }
    }
    
    func createInfoRow(startTime: String, totalFrames: Int) {
        guard let fileURL = saveURL else {
            print("No save path found")
            return
        }
        
        let patientID = NSUUID().uuidString
        let task = ""
        
        let (portraitVideoResolution, portraitDepthResolution) = processorSettings.getPortraitResolutions()
        
        // Create string to hold the row's data
        let data = "\(patientID),\(task),\(startTime),\(processorSettings.numLandmarks),\(portraitVideoResolution.width),\(portraitVideoResolution.height),\(portraitDepthResolution.width),\(portraitDepthResolution.height),\(totalFrames),\n"
        
        // Convert string to data buffer
        guard let dataBuffer = data.data(using: String.Encoding.utf8) else {
            print("Failed to convert data from type String to type Data.")
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
            print("Failed to write data to file.")
        }
    }
    
    
    
}
