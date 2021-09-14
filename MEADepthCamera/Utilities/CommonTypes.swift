//
//  CommonTypes.swift
//  MEADepthCamera
//
//  Created by Will on 7/30/21.
//

import AVFoundation

struct SavedFile: Codable {
    let outputType: OutputType
    let lastPathComponent: String
}

struct SavedRecording: Codable {
    let name: String
    let folderURL: URL
    let duration: Double?
    let task: SavedTask?
    var savedFiles: [SavedFile]
}

struct SavedUseCase: Codable {
    var id: UUID
    var title: String
    var date: Date
    var subjectID: String
    var recordings: [SavedRecording]
    var notes: String? = nil
}

struct SavedTask: Codable {
    let name: String
    let fileNameLabel: String?
    let instructions: String?
    let repTime: Int?
    let repetitions: Int?
    let recordVideo: Bool?
    let recordAudio: Bool?
}
