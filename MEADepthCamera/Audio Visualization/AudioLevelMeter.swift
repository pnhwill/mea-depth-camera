//
//  AudioLevelMeter.swift
//  MEADepthCamera
//
//  Created by Will on 12/2/21.
//

import UIKit

class AudioLevelMeter: UIView {
    
    private let minDecibels: Float = -80.0

    private var peakLevelMeter: LevelMeterView
    private var meanLevelMeter: LevelMeterView

    override init(frame: CGRect) {
        peakLevelMeter = LevelMeterView(frame: frame, fillColor: UIColor.systemGreen.withAlphaComponent(0.5))
        meanLevelMeter = LevelMeterView(frame: frame, fillColor: UIColor.systemGreen)
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(peakLevelMeter)
        addSubview(meanLevelMeter)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        return value.clamp(min: minDecibels, max: 0.0).normalize(from: minDecibels...0.0, to: 0.0...1.0)
    }
}

class LevelMeterView: UIView {
    
    var fillColor: UIColor
    
    /// The current level, from 0 - 1.
    var level: CGFloat = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
//    private var peakLevel: CGFloat = 0.0
    
    init(frame: CGRect, fillColor: UIColor) {
        self.fillColor = fillColor
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let levelRect = CGRect(x: 0, y: bounds.height * (1.0 - level), width: bounds.width, height: bounds.height * level)
        context.setFillColor(fillColor.cgColor)
        context.fill(levelRect)
    }
}

extension Comparable {
    func clamp(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
}

extension FloatingPoint {
    func normalize(from oldRange: ClosedRange<Self>, to newRange: ClosedRange<Self>) -> Self {
        return (newRange.upperBound - newRange.lowerBound) * ((self - oldRange.lowerBound) / (oldRange.upperBound - oldRange.lowerBound)) + newRange.lowerBound
    }
}
