//
//  CSVFileWriter.swift
//  MEADepthCamera
//
//  Created by Will on 12/9/21.
//

import Foundation

/// Protocol for file writers that write comma-delimited `String` data to a CSV file.
protocol CSVFileWriter: FileWriter {
    
}

extension CSVFileWriter {
    /// Writes the columns labels to the first row in the CSV file.
    func writeColumnLabels(_ columnLabels: String) {
        do {
            try columnLabels.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Failed to write to file: \(error)")
        }
    }
}
