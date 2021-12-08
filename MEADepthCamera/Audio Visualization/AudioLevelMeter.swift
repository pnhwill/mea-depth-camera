//
//  AudioLevelMeter.swift
//  MEADepthCamera
//
//  Created by Will on 12/2/21.
//

import UIKit

/// Main UIView subclass for the audio level meter that contains and updates LevelMeterBar subviews for the peak and mean audio decibel levels.
class AudioLevelMeter: UIView {
    
    private let minDecibels: Float = -80.0

    private var peakLevelMeter: LevelMeterBar
    private var meanLevelMeter: LevelMeterBar

    override init(frame: CGRect) {
        peakLevelMeter = LevelMeterBar(frame: frame, fillColor: UIColor.systemGreen.withAlphaComponent(0.5))
        meanLevelMeter = LevelMeterBar(frame: frame, fillColor: UIColor.systemGreen)
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(peakLevelMeter)
        addSubview(meanLevelMeter)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Update Display
    
    func refresh(peakDecibels: Float, meanDecibels: Float) {
        let peakLevel = clampAndNormalize(peakDecibels)
        let meanLevel = clampAndNormalize(meanDecibels)
//        print("peak: \(peakLevel)")
//        print("mean: \(meanLevel)")
        DispatchQueue.main.async {
            self.peakLevelMeter.level = CGFloat(peakLevel)
            self.meanLevelMeter.level = CGFloat(meanLevel)
        }
    }
    
    private func clampAndNormalize(_ value: Float) -> Float {
        return value.clamp(min: minDecibels, max: 0.0)
                    .normalize(from: minDecibels...0.0, to: 0.0...1.0)
    }
}

