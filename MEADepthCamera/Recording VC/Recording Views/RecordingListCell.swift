//
//  RecordingListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListCell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var taskLabel: UILabel!
    @IBOutlet weak var filesCountLabel: UILabel!
    @IBOutlet weak var isProcessedLabel: UILabel!
    
    func configure(name: String?, durationText: String, taskText: String, filesCount: Int, isProcessed: Bool) {
        nameLabel.text = name
        durationLabel.text = durationText
        taskLabel.text = taskText
        filesCountLabel.text = String(filesCount) + " Files"
        isProcessedLabel.text = "Processed: " + String(isProcessed)
    }
}
