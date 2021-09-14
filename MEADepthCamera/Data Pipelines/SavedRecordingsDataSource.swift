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
    
    var processorSettings: ProcessorSettings?
    
    // Core Data providers
    
    lazy var recordingProvider: RecordingProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = RecordingProvider(with: container)
        return provider
    }()
    
    lazy var outputFileProvider: OutputFileProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = OutputFileProvider(with: container)
        return provider
    }()
    
    init() {
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Documents directory.")
        }
        self.baseURL = docsURL
    }
    
    func addRecording(_ folderURL: URL, outputFiles: [OutputType: URL], processorSettings: ProcessorSettings) {
        let folderName = folderURL.lastPathComponent
        var savedFiles = [SavedFile]()
        for file in outputFiles {
            let outputType = file.key
            let fileName = file.value.lastPathComponent
            let newFile = SavedFile(outputType: outputType, lastPathComponent: fileName)
            savedFiles.append(newFile)
        }
        savedRecording = SavedRecording(name: folderName, folderURL: folderURL, duration: nil, task: nil, savedFiles: savedFiles)
        self.processorSettings = processorSettings
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
        let context = recordingProvider.persistentContainer.newBackgroundContext()
        // Saves a recording to the persistent storage
        recordingProvider.add(in: context, shouldSave: false, completionHandler: { newRecording in
            newRecording.useCase = useCase
            newRecording.task = task
            newRecording.folderURL = recording.folderURL
            newRecording.name = recording.name
            newRecording.duration = recording.duration ?? 0
            newRecording.processorSettings = self.processorSettings
            
            let outputFiles = recording.savedFiles.map { self.saveFile($0, to: newRecording) }
            newRecording.files = NSSet(array: outputFiles as [Any])
            
            useCase.addToRecordings(newRecording)
            task.addToRecordings(newRecording)
            
            self.recordingProvider.persistentContainer.saveContext(backgroundContext: context, with: .addRecording)
        })
    }
    
    func saveFile(_ file: SavedFile, to recording: Recording) -> OutputFile? {
        // Saves an output file to the persistent storage
        guard let context = recording.managedObjectContext else { return nil }
        var outputFile: OutputFile?
        outputFileProvider.add(in: context, shouldSave: false, completionHandler: { newFile in
            newFile.fileName = file.lastPathComponent
            newFile.fileURL = recording.folderURL?.appendingPathComponent(file.lastPathComponent)
            newFile.outputType = file.outputType.rawValue
            newFile.recording = recording
            outputFile = newFile
        })
        print(outputFile!.fileName!)
        return outputFile
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
