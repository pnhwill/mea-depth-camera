//
//  DataPipeline.swift
//  MEADepthCamera
//
//  Created by Will on 8/6/21.
//

import Foundation

protocol DataPipeline: AnyObject {
    func createFolder() -> URL?
    func createFileURL(in folderURL: URL, nameLabel: String, fileType: String) -> URL?
}

extension DataPipeline {
    
    func createFolder() -> URL? {
        // Get or create documents directory
        var docURL: URL?
        do {
            docURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            print("Error getting documents directory: \(error)")
            return nil
        }
        // Get current datetime and format the folder name
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timeStamp = formatter.string(from: date)
        // Create URL for folder inside documents path
        guard let dataURL = docURL?.appendingPathComponent(timeStamp, isDirectory: true) else {
            print("Failed to append folder name to documents URL")
            return nil
        }
        // Create folder at desired path if it does not already exist
        if !FileManager.default.fileExists(atPath: dataURL.path) {
            do {
                try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder in documents directory: \(error.localizedDescription)")
            }
        }
        return dataURL
    }
    
    func createFileURL(in folderURL: URL, nameLabel: String, fileType: String) -> URL? {
        let folderName = folderURL.lastPathComponent
        let fileName = folderName + "_" + nameLabel
        
        let fileURL = folderURL.appendingPathComponent(fileName).appendingPathExtension(fileType)
        
        return fileURL
    }
}
