//
//  RecordingListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListCell: UITableViewCell {
    
    @IBOutlet weak var folderLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var filesCountLabel: UILabel!
    
    func configure(folderName: String, durationText: String, filesCountText: String) {
        folderLabel.text = folderName
        durationLabel.text = durationText
        filesCountLabel.text = filesCountText
    }
}
