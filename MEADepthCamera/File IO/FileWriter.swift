//
//  FileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import Foundation

/// Protocol for all file writer types.
protocol FileWriter: AnyObject, NameDescribable {
    
    /// The output type of the file being written to.
    var outputType: OutputType { get }
    
    /// The URL that the file is written to.
    var fileURL: URL { get }
    
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
