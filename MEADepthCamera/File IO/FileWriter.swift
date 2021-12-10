//
//  FileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import Foundation

/// Protocol for all file writer types.
protocol FileWriter: AnyObject {
    
    /// The type of output file that this file writer creates and writes data to.
    var outputType: OutputType { get }
    
}

extension FileWriter {
    /// Creates and returns a URL in the specified folder for a file whose name and extension is determined by the specified `OutputType`.
    static func createFileURL(in folderURL: URL, outputType: OutputType) -> URL {
        let folderName = folderURL.lastPathComponent
        let fileName = folderName + "_" + outputType.rawValue
        
        let fileURL = folderURL.appendingPathComponent(fileName).appendingPathExtension(outputType.fileExtension)
        
        return fileURL
    }
}
