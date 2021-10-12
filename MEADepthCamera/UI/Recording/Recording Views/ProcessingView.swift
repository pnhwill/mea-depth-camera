//
//  ProcessingView.swift
//  MEADepthCamera
//
//  Created by Will on 8/30/21.
//
/*
Abstract:
A UIView subclass that manages the section processing header for the recording list table view.
*/

import UIKit

class ProcessingView: UITableViewHeaderFooterView {
    typealias StartStopAction = (Int) -> Void
    
    var section: Int = -1
    
    @IBOutlet private weak var startStopButton: UIButton!
    @IBOutlet private weak var frameCounterLabel: UILabel!
    @IBOutlet private weak var progressBar: UIProgressView!
    
    private var startStopAction: StartStopAction?
    
    func configure(isProcessing: Bool, frameCounterText: String, progress: Float?, startStopAction: @escaping StartStopAction) {
        let buttonImage = isProcessing ? UIImage(systemName: "stop.fill") : UIImage(systemName: "play.fill")
        startStopButton.setBackgroundImage(buttonImage, for: [])
        if !startStopButton.isEnabled {
            startStopButton.isEnabled = true
        }
        frameCounterLabel.text = frameCounterText
        progressBar.isHidden = !isProcessing
        if let progress = progress {
            progressBar.setProgress(progress, animated: true)
        }
        self.startStopAction = startStopAction
    }
    
    @IBAction func handleStartStopButton(_ sender: UIButton) {
        startStopButton.isEnabled = false
        startStopAction?(section)
    }
}
