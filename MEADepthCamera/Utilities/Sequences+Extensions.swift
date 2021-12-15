//
//  Sequences+Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 12/14/21.
//
/// Defines convenience and utility extensions for Sequence and Collection types.

import Foundation

// MARK: Sequence
extension Sequence where Element: Identifiable {
    func groupingByID() -> [Element.ID: [Element]] {
        return Dictionary(grouping: self, by: { $0.id })
    }
    
    func groupingByUniqueID() -> [Element.ID: Element] {
        return Dictionary(uniqueKeysWithValues: self.map { ($0.id, $0) })
    }
}

// MARK: ClosedRange
extension ClosedRange where Bound: AdditiveArithmetic {
    var diameter: Bound { upperBound - lowerBound }
}

// MARK: Array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
