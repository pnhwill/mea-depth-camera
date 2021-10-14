//
//  TaskListCell.swift
//  MEADepthCamera
//
//  Created by Will on 9/22/21.
//

import UIKit

class TaskListCell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet weak var recordingsCountLabel: UILabel!
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var instructionsButton: UIButton!
    
    func configure(name: String, recordingsCountText: String) {
        nameLabel.text = name
        recordingsCountLabel.text = recordingsCountText
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startButton.layer.cornerRadius = 10
        startButton.layer.masksToBounds = true
        instructionsButton.layer.cornerRadius = 10
        instructionsButton.layer.masksToBounds = true
    }
}
