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
    
    // Core Data
    var persistentContainer: PersistentContainer?
    
    init() {
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Documents directory.")
        }
        self.baseURL = docsURL
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
    
    func saveRecording(to useCase: UseCase, for task: Task) {
        guard let recording = savedRecording else { return }
        // Saves a recording to the persistent storage
        if let context = persistentContainer?.viewContext {
            context.performAndWait {
                let newRecording = Recording(context: context)
                newRecording.useCase = useCase
                newRecording.task = task
                newRecording.folderURL = recording.folderURL
                newRecording.name = recording.name
                newRecording.duration = recording.duration ?? 0
                newRecording.id = UUID()
                
                let outputFiles = recording.savedFiles.map { self.saveFile($0, to: newRecording) }
                newRecording.files = NSSet(array: outputFiles as [Any])
                
                useCase.addToRecordings(newRecording)
                task.addToRecordings(newRecording)
//                if let useCaseTasks = useCase.tasks, !useCaseTasks.contains(task) {
//                    useCase.addToTasks(task)
//                    task.addToUseCases(useCase)
//                }
                
                self.persistentContainer?.saveContext(backgroundContext: context)
                context.refresh(newRecording, mergeChanges: true)
                context.refresh(useCase, mergeChanges: true)
                context.refresh(task, mergeChanges: true)
            }
        }
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
