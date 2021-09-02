//
//  RecordingListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListCell: UITableViewCell {
    
    @IBOutlet var taskLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var folderLabel: UILabel!
    @IBOutlet weak var filesCountLabel: UILabel!
    @IBOutlet weak var isProcessedLabel: UILabel!
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var instructionsButton: UIButton!
    
    func configure(taskName: String?, durationText: String?, folderName: String?, filesCount: Int?, isProcessed: Bool?) {
        taskLabel.text = taskName
        durationLabel.text = durationText
        durationLabel.isHidden = durationText == nil
        folderLabel.text = folderName
        folderLabel.isHidden = folderName == nil
        if let filesCount = filesCount {
            filesCountLabel.text = String(filesCount) + " Files"
        }
        filesCountLabel.isHidden = filesCount == nil
        if let isProcessed = isProcessed {
            let isProcessedText = isProcessed ? "Yes" : "No"
            isProcessedLabel.text = "Processed: " + isProcessedText
        }
        isProcessedLabel.isHidden = isProcessed == nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startButton.layer.cornerRadius = 10
        startButton.layer.masksToBounds = true
        instructionsButton.layer.cornerRadius = 10
        instructionsButton.layer.masksToBounds = true
    }
}
