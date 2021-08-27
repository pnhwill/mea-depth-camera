//
//  SavedRecordingsDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/3/21.
//
/*
 Abstract:
 Data source implementing the storage abstraction to keep face capture recording sessions for the data pipelines
 */

import Foundation
import CoreData

class SavedRecordingsDataSource {
    
    let baseURL: URL
    let fileManager = FileManager.default
    var savedRecording: SavedRecording?
    var storedRecordingsCount: Int
    
    // Core Data
    var persistentContainer: PersistentContainer?
    
    init(storedRecordingsCount: Int) {
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Documents directory.")
        }
        self.baseURL = docsURL
        self.storedRecordingsCount = storedRecordingsCount
    }
    
    func addRecording(_ folderURL: URL, outputFiles: [OutputType: URL]) {
        let folderName = folderURL.lastPathComponent
        var savedFiles = [SavedFile]()
        for file in outputFiles {
            let outputType = file.key
            let fileName = file.value.lastPathComponent
            let newFile = SavedFile(outputType: outputType, lastPathComponent: fileName)
            savedFiles.append(newFile)
        }
        savedRecording = SavedRecording(name: folderName, folderURL: folderURL, duration: nil, task: nil, savedFiles: savedFiles)
    }
    
    func addFiles(to savedRecording: inout SavedRecording, newFiles: [OutputType: URL]) {
        for file in newFiles {
            let outputType = file.key
            let fileName = file.value.lastPathComponent
            let newFile = SavedFile(outputType: outputType, lastPathComponent: fileName)
            savedRecording.savedFiles.append(newFile)
        }
    }
    
    func saveRecording(to useCase: UseCase) {
        guard let recording = savedRecording else { return }
        // Saves a recording to the persistent storage
        var newRecording: Recording?
        persistentContainer?.performBackgroundTask { context in
            context.parent = self.persistentContainer?.viewContext
            newRecording = Recording(context: context)
            newRecording?.useCase = useCase
            newRecording?.folderURL = recording.folderURL
            newRecording?.name = recording.name
            newRecording?.duration = recording.duration ?? 0
            let outputFiles = recording.savedFiles.map { self.saveFile($0, to: newRecording!) }
            newRecording?.files = NSSet(array: outputFiles as [Any])
//            newRecording?.task = recording.task
            self.persistentContainer?.saveContext(backgroundContext: context)
//            context.refresh(newRecording!, mergeChanges: true)
        }
        storedRecordingsCount += 1
    }
    
    func saveFile(_ file: SavedFile, to recording: Recording) -> OutputFile? {
        // Saves an output file to the persistent storage
        guard let context = recording.managedObjectContext else { return nil }
        
        let newFile = OutputFile(context: context)
        newFile.fileName = file.lastPathComponent
        newFile.fileURL = recording.folderURL?.appendingPathComponent(file.lastPathComponent)
        newFile.id = UUID()
        newFile.outputType = file.outputType.rawValue
        newFile.recording = recording
        
        return newFile
    }
    
//    func removeSavedRecording(at index: Int) throws {
//        let savedRecording = savedRecordings[index]
//        try fileManager.removeItem(at: savedRecording.folderURL)
//        savedRecordings.remove(at: index)
//    }
//
//    func removeAllSavedRecordings() {
//        guard let folders = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
//            return
//        }
//        for folder in folders {
//            try? fileManager.removeItem(at: folder)
//        }
//        savedRecordings.removeAll()
//    }
//
//    func readRecordings() {
//
//    }
    
    
}
