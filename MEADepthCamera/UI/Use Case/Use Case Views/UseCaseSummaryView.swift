//
//  UseCaseSummaryView.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class UseCaseSummaryView: UIView {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var subjectIDLabel: UILabel!
    
    func configure(title: String?, subjectIDText: String?) {
        titleLabel.text = title
        if let subjectIDText = subjectIDText {
            subjectIDLabel.text = "Subject ID: " + subjectIDText
            subjectIDLabel.isHidden = false
        } else {
            subjectIDLabel.isHidden = true
        }
    }
    
}
