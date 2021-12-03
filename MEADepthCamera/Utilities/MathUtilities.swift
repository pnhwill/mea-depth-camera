//
//  MathUtilities.swift
//  MEADepthCamera
//
//  Created by Will on 12/3/21.
//

import Foundation

// MARK: - Functions

func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
    return CGFloat(Double(degrees) * Double.pi / 180.0)
}

// MARK: - Extensions

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

extension CGPoint {
    /// Clamp a CGPoint within a certain bounds.
    mutating func clamp(bounds: CGSize) {
        self.x = min(bounds.width, max(self.x, 0.0))
        self.y = min(bounds.height, max(self.y, 0.0))
    }
}

extension CGSize {
    func rounded() -> CGSize {
        return CGSize(width: self.width.rounded(), height: self.height.rounded())
    }
}
