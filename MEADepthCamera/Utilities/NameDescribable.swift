//
//  NameDescribable.swift
//  MEADepthCamera
//
//  Created by Will on 12/10/21.
//

import Foundation

/// Protocol to get string of type name.
protocol NameDescribable {
    var typeName: String { get }
    static var typeName: String { get }
}

extension NameDescribable {
    var typeName: String {
        return String(describing: type(of: self))
    }

    static var typeName: String {
        return String(describing: self)
    }
}
