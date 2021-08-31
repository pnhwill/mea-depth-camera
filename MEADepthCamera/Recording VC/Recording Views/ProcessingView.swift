//
//  ProcessingView.swift
//  MEADepthCamera
//
//  Created by Will on 8/30/21.
//

import UIKit

class ProcessingView: UIView {
    typealias StartStopAction = () -> Void
    
    @IBOutlet private weak var startStopButton: UIButton!
    @IBOutlet private weak var frameCounterLabel: UILabel!
    @IBOutlet private weak var progressBar: UIProgressView!
    
    private var startStopAction: StartStopAction?
    
    func configure(isProcessing: Bool, totalFrames: Int, processedFrames: Int, startStopAction: @escaping StartStopAction) {
        let buttonImage = isProcessing ? UIImage(systemName: "play.fill") : UIImage(systemName: "stop.fill")
        startStopButton.setBackgroundImage(buttonImage, for: [])
        
        let frameCounterText = "Frame: \(processedFrames)/\(totalFrames)"
        frameCounterLabel.text = isProcessing ? frameCounterText : "Tap to Start Processing"
        
        let progress = Float(processedFrames) / Float(totalFrames)
        progressBar.setProgress(progress, animated: true)
        progressBar.isHidden = !isProcessing
        
        self.startStopAction = startStopAction
    }
    
    @IBAction func startStopButtonTriggered(_ sender: UIButton) {
        startStopAction?()
    }
    
}
