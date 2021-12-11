//
//  CaptureRecordingDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/3/21.
//

import CoreData

/// Data source implementing the storage abstraction to keep face capture recording sessions for the data pipelines.
class CaptureRecordingDataSource {
    
    struct CaptureFile {
        let outputType: OutputType
        let fileName: String
    }

    struct CaptureRecording {
        let name: String
        let folderURL: URL
        let duration: Double?
        var savedFiles: [CaptureFile]
    }
    
    private let fileManager = FileManager.default
    private let baseURL: URL
    
    private var savedRecording: CaptureRecording?
    private var processorSettings: ProcessorSettings?
    
    private lazy var recordingProvider: RecordingProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = RecordingProvider(with: container)
        return provider
    }()
    
    private lazy var outputFileProvider: OutputFileProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = OutputFileProvider(with: container)
        return provider
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        return formatter
    }()
    
    init?() {
        do {
            let docsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            self.baseURL = docsURL
        } catch {
            print("Data source initialization failure: Unable to locate Documents directory (\(error))")
            return nil
        }
    }
    
    func createFolder() -> URL? {
        // Get current datetime and format the folder name.
        let date = Date()
        let timeStamp = dateFormatter.string(from: date)
        // Create URL for folder inside documents path.
        let dataURL = baseURL.appendingPathComponent(timeStamp, isDirectory: true)
        // Create folder at desired path if it does not already exist.
        if !fileManager.fileExists(atPath: dataURL.path) {
            do {
                try fileManager.createDirectory(at: dataURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder in documents directory: \(error.localizedDescription)")
            }
        }
        return dataURL
    }
    
    func addRecording(_ folderURL: URL, outputFiles: [OutputType: URL], processorSettings: ProcessorSettings) {
        let folderName = folderURL.lastPathComponent
        let savedFiles = addFiles(outputFiles)
        savedRecording = CaptureRecording(name: folderName, folderURL: folderURL, duration: nil, savedFiles: savedFiles)
        self.processorSettings = processorSettings
    }
    
    func saveRecording(to useCase: UseCase, for task: Task) {
        guard let recording = savedRecording, let context = useCase.managedObjectContext else { return }
        
        // Saves a recording to the persistent storage
        recordingProvider.add(in: context, shouldSave: false, completionHandler: { newRecording in
            newRecording.useCase = useCase
            newRecording.task = task
            newRecording.folderURL = recording.folderURL
            print("Recording saved in folder named: \(recording.folderURL)")
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
    
    private func addFiles(_ newFiles: [OutputType: URL]) -> [CaptureFile] {
        var savedFiles = [CaptureFile]()
        for file in newFiles {
            let outputType = file.key
            let fileName = file.value.lastPathComponent
            let newFile = CaptureFile(outputType: outputType, fileName: fileName)
            savedFiles.append(newFile)
        }
        return savedFiles
    }
    
    private func saveFile(_ file: CaptureFile, to recording: Recording) -> OutputFile? {
        // Saves an output file to the persistent storage
        guard let context = recording.managedObjectContext else { return nil }
        var outputFile: OutputFile?
        outputFileProvider.add(in: context, shouldSave: false, completionHandler: { newFile in
            newFile.fileName = file.fileName
            newFile.fileURL = recording.folderURL?.appendingPathComponent(file.fileName)
            newFile.outputType = file.outputType.rawValue
            newFile.recording = recording
            outputFile = newFile
        })
        return outputFile
    }
}
