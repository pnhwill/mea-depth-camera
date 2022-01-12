//
//  AudioVisualizerViewController.swift
//  MEADepthCamera
//
//  Created by Will on 11/28/21.
//

import UIKit
import CoreMedia
import Accelerate

/// A view controller that displays three real-time audio signal visualizations.
class AudioVisualizerViewController: UIViewController {
    
    /// The audio spectrogram layer.
    let audioSpectrogram = AudioSpectrogram()
    
    /// Audio waveform layer.
    let audioShapeLayer = CAShapeLayer()
    
    /// Audio level meter view.
    var audioLevelMeter = AudioLevelMeter()
    
    /// Audio visualization processing queue.
    let audioQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("audioQueue"),
        qos: .userInitiated,
        autoreleaseFrequency: .workItem)
    
    // MARK: VC Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        view.layer.addSublayer(audioSpectrogram)
        view.layer.addSublayer(audioShapeLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let levelMeterFrame = CGRect(origin: view.bounds.origin, size: CGSize(width: 100, height: view.bounds.height))
        audioLevelMeter = AudioLevelMeter(frame: levelMeterFrame)
        view.addSubview(audioLevelMeter)
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
            // Spectrogram
            self.audioSpectrogram.captureOutput(didOutput: sampleBuffer)
            
            // Waveform and Level
            if let data = AudioUtilities.getAudioData(sampleBuffer) {
                
                var samples = [Float](repeating: 0, count: data.count)
                vDSP.convertElements(of: data, to: &samples)
                
                self.displayWaveInLayer(self.audioShapeLayer,
                                        ofColor: .red,
                                        signal: samples,
                                        min: AudioUtilities.minFloat,
                                        max: AudioUtilities.maxFloat,
                                        hScale: 1)
                
                let peakLevel = AudioUtilities.peakDecibelLevel(of: samples)
                let timescale = Float(CMSampleBufferGetDuration(sampleBuffer).timescale)
                let meanLevels = AudioUtilities.meanDecibelLevel(of: samples, window: 1.0, sampleRate: timescale)
                
                self.audioLevelMeter.refresh(peakDecibels: peakLevel, meanDecibels: meanLevels[0])
                
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
