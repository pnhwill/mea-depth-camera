//
//  MathUtilities.swift
//  MEADepthCamera
//
//  Created by Will on 12/3/21.
//

import Foundation

// MARK: Global Functions

func degreesToRadians<F: FloatingPoint>(_ degrees: F) -> F {
    return degrees * .pi / 180
}

func radiansToDegrees<F: FloatingPoint>(_ radians: F) -> F {
    return radians * 180 / .pi
}

// MARK: Numerics

extension Comparable {
    func clamp(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
}

extension FloatingPoint {
    func normalize(from oldRange: ClosedRange<Self>, to newRange: ClosedRange<Self>) -> Self {
        return newRange.diameter * ((self - oldRange.lowerBound) / oldRange.diameter) + newRange.lowerBound
    }
}

// MARK: Collections

extension ClosedRange where Bound: AdditiveArithmetic {
    var diameter: Bound { upperBound - lowerBound }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: Core Graphics

extension CGPoint {
    /// Clamp a CGPoint within a certain bounds.
    mutating func clamp(bounds: CGSize) {
        self.x = min(bounds.width, max(self.x, 0.0))
        self.y = min(bounds.height, max(self.y, 0.0))
    }
}

extension CGSize {
    var rounded: Self {
        CGSize(width: self.width.rounded(), height: self.height.rounded())
    }
}

extension CGRect {
    var midpoint: CGPoint { CGPoint(x: midX, y: midY) }
}

// MARK: SIMD

extension SIMD where Scalar: BinaryFloatingPoint {
    init(_ scalars: CGFloat...) {
        self.init(scalars.map { Scalar($0) })
    }
}

extension SIMD where Scalar == Float {
    init(_ numbers: NSNumber...) {
        self.init(numbers.map { Float(truncating: $0) })
    }
}

extension SIMD2 where Scalar: BinaryFloatingPoint {
    init(_ point: CGPoint) {
        self.init(point.x, point.y)
    }
    init(_ size: CGSize) {
        self.init(size.width, size.height)
    }
}

