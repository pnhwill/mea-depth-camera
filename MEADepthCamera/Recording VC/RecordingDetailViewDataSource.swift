//
//  RecordingDetailViewDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailViewDataSource: NSObject {
    
    enum RecordingRow: Int, CaseIterable {
        case name
        case task
        case duration
        case filesCount
        case isProcessed
        
        func displayText(for recording: Recording) -> String? {
            switch self {
            case .name:
                return recording.name
            case .task:
                return recording.task?.name
            case .duration:
                return recording.durationText()
            case .filesCount:
                return String(recording.filesCount)
            case .isProcessed:
                return recording.isProcessed ? "Yes" : "No"
            }
        }
    }
    
    // Current recording
    var recording: Recording
    
    init(recording: Recording) {
        self.recording = recording
    }
    
    
    
}

extension RecordingDetailViewDataSource: UITableViewDataSource {
    static let recordingDetailCellIdentifier = "RecordingDetailCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        RecordingRow.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.recordingDetailCellIdentifier, for: indexPath)
        let row = RecordingRow(rawValue: indexPath.row)
        cell.textLabel?.text = row?.displayText(for: recording)
        //cell.imageView?.image = row?.cellImage
        return cell
    }
    
}
