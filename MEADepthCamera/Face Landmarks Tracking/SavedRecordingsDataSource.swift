//
//  SavedRecordingsDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/3/21.
//
/*
 Abstract:
 Data source implementing the storage abstraction to keep face capture recording sessions
 */

import Foundation

class SavedRecordingsDataSource {
    
    let baseURL: URL
    var savedRecordings = [SavedRecording]()
    
    init() {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Documents directory.")
        }
        self.baseURL = docsURL
    }
    
    func saveRecording(_ folderURL: URL, outputFiles: [OutputType: URL]) {
        let folderName = folderURL.lastPathComponent
        var savedFiles = [SavedFile]()
        for file in outputFiles {
            let outputType = file.key
            let fileName = file.value.lastPathComponent
            let newFile = SavedFile(outputType: outputType, lastPathComponent: fileName)
            savedFiles.append(newFile)
        }
        let newRecording = SavedRecording(name: folderName, folderURL: folderURL, savedFiles: savedFiles)
        savedRecordings.append(newRecording)
    }
    
    func removeSavedRecording(at index: Int) throws {
        let fileMgr = FileManager.default
        let savedRecording = savedRecordings[index]
        try fileMgr.removeItem(at: savedRecording.folderURL)
        savedRecordings.remove(at: index)
    }
    
    func removeAllSavedRecordings() {
        let fileMgr = FileManager.default
        guard let folders = try? fileMgr.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
            return
        }
        for folder in folders {
            try? fileMgr.removeItem(at: folder)
        }
        savedRecordings.removeAll()
    }

}
