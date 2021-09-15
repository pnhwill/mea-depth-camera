//
//  ProcessorSettingsToDataTransformer.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//
/*
Abstract:
A tranformer class that transforms NSData to ProcessorSettings and vice versa.
*/

import Foundation

class ProcessorSettingsToDataTransformer: NSSecureUnarchiveFromDataTransformer {
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override class func transformedValueClass() -> AnyClass {
        return ProcessorSettings.self
    }
    
    override class var allowedTopLevelClasses: [AnyClass] {
        return [ProcessorSettings.self]
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            fatalError("Wrong data type: value must be a Data object; received \(type(of: value))")
        }
        return super.transformedValue(data)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let processorSettings = value as? ProcessorSettings else {
            fatalError("Wrong data type: value must be a ProcessorSettings object; received \(type(of: value))")
        }
        return super.reverseTransformedValue(processorSettings)
    }
}

extension NSValueTransformerName {
    static let processorSettingsToDataTransformer = NSValueTransformerName(rawValue: "ProcessorSettingsToDataTransformer")
}
