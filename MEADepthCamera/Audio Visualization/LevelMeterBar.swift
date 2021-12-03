//
//  LevelMeterBar.swift
//  MEADepthCamera
//
//  Created by Will on 12/3/21.
//

import UIKit

class LevelMeterBar: UIView {
    
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
