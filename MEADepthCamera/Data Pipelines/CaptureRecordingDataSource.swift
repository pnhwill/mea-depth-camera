//
//  CaptureRecordingDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/3/21.
//

import CoreData
import OSLog

/// Data source implementing the storage abstraction to keep face capture recording sessions for the data pipelines.
final class CaptureRecordingDataSource {
    
    struct CaptureFile {
        let outputType: OutputType
        let fileName: String
    }

    struct CaptureRecording {
        let name: String
        let folderURL: URL
        var savedFiles: [CaptureFile]
    }
    
    private let fileManager = FileManager.default
    
    private var savedRecording: CaptureRecording?
    private var processorSettings: ProcessorSettings?
    private var startTime: Date?
    private var useCaseFolder: URL?
    
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
    
    private let logger = Logger.Category.fileIO.logger
    
    init?(useCase: UseCase) {
        guard let folderURL = useCase.folderURL else {
            logger.error("Data source initialization failure: Unable to locate Use Case directory.")
            return nil
        }
        self.useCaseFolder = folderURL
    }
    
    // MARK: Directories
    
    func createRecordingFolder(prefix: String) -> URL? {
        guard let useCaseFolder = useCaseFolder else { return nil }
        // Get current datetime and format the folder name.
        let date = Date()
        startTime = date
        let timeStamp = dateFormatter.string(from: date)
        let pathName = prefix + "_" + timeStamp
        // Create URL for folder inside documents path.
        let dataURL = useCaseFolder.appendingPathComponent(pathName, isDirectory: true)
        // Create folder at desired path if it does not already exist.
        if !fileManager.fileExists(atPath: dataURL.path) {
            do {
                try fileManager.createDirectory(at: dataURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("Error creating recording folder in use case directory: \(error.localizedDescription)")
                return nil
            }
        }
        return dataURL
    }
    
    // MARK: Recordings
    
    func addRecording(_ folderURL: URL, outputFiles: [OutputType: URL], processorSettings: ProcessorSettings) {
        let folderName = folderURL.lastPathComponent
        let savedFiles = addFiles(outputFiles)
        savedRecording = CaptureRecording(name: folderName, folderURL: folderURL, savedFiles: savedFiles)
        self.processorSettings = processorSettings
    }
    
    /// Saves the current recording to the persistent storage.
    func saveRecording(to useCase: UseCase, for task: Task) {
        guard let recording = savedRecording,
              let startTime = startTime,
              let context = useCase.managedObjectContext
        else { return }
        let endTime = Date()
        let duration = DateInterval(start: startTime, end: endTime)
        
        recordingProvider.add(in: context, shouldSave: false, completionHandler: { newRecording in
            newRecording.useCase = useCase
            newRecording.task = task
            newRecording.folderURL = recording.folderURL
            self.logger.notice("Recording saved in folder named: \(recording.folderURL)")
            newRecording.name = recording.name
            newRecording.duration = duration.duration
            newRecording.processorSettings = self.processorSettings
            newRecording.startTime = startTime
            
            let outputFiles = recording.savedFiles.map { self.saveFile($0, to: newRecording) }
            newRecording.addToFiles(NSSet(array: outputFiles as [Any]))
            
            useCase.addToRecordings(newRecording)
            task.addToRecordings(newRecording)
            
            self.recordingProvider.persistentContainer.saveContext(backgroundContext: context, with: .addRecording)
            self.reset()
        })
    }
    
    // MARK: Output Files
    
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
    
    /// Saves an output file to the persistent storage.
    private func saveFile(_ file: CaptureFile, to recording: Recording) -> OutputFile? {
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
    
    // MARK: Reset
    
    private func reset() {
        savedRecording = nil
        processorSettings = nil
        startTime = nil
    }
}
