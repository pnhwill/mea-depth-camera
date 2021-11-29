//
//  AudioVisualizerViewController.swift
//  MEADepthCamera
//
//  Created by Will on 11/28/21.
//

import UIKit
import CoreMedia
import Accelerate

/// A view controller that displays two real-time audio signal visualizations.
class AudioVisualizerViewController: UIViewController {
    
    /// The audio spectrogram layer.
    let audioSpectrogram = AudioSpectrogram()
    
    /// Audio waveform layer.
    let audioShapeLayer = CAShapeLayer()
    
    /// Audio visualization processing queue.
    let audioQueue = DispatchQueue(label: Bundle.main.reverseDNS(suffix: "audioQueue"),
                                   qos: .userInitiated,
                                   attributes: [],
                                   autoreleaseFrequency: .workItem)
    
    // MARK: VC Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        view.layer.addSublayer(audioSpectrogram)
        view.layer.addSublayer(audioShapeLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let (topRect, bottomRect) = view.frame.divided(atDistance: view.frame.height/2, from: .minYEdge)
        audioSpectrogram.frame = topRect
        audioShapeLayer.frame = bottomRect
    }
    
    // MARK: Render Audio
    func renderAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async {
            self.audioSpectrogram.captureOutput(didOutput: sampleBuffer)
            
            if let data = AudioUtilities.getAudioData(sampleBuffer) {
                
                var samples = [Float](repeating: 0, count: data.count)
                
                vDSP.convertElements(of: data, to: &samples)
                
                self.displayWaveInLayer(self.audioShapeLayer,
                                        ofColor: .red,
                                        signal: samples,
                                        min: Float(Int16.min),
                                        max: Float(Int16.max),
                                        hScale: 1)
            } else {
                print("Unable to parse the audio resource.")
            }
        }
    }
}

// MARK: Draw Waveform
extension AudioVisualizerViewController {
    private func displayWaveInLayer(_ targetLayer: CAShapeLayer,
                                    ofColor color: UIColor,
                                    signal: [Float],
                                    min: Float?, max: Float?,
                                    hScale: CGFloat) {
        DispatchQueue.main.async {
            GraphUtility.drawGraphInLayer(targetLayer,
                                          strokeColor: color.cgColor,
                                          lineWidth: 3,
                                          values: signal,
                                          minimum: min,
                                          maximum: max,
                                          hScale: hScale)
        }
    }
}
