//
//  JSONError.swift
//  MEADepthCamera
//
//  Created by Will on 9/8/21.
//
/*
Abstract:
An enumeration of JSON-loaded (experiment & task) fetch and consumption errors.
*/

import Foundation

// MARK: JSON Error
enum JSONError: Error {
    case wrongDataFormat(error: Error)
    case missingData
    case batchInsertError
    case unexpectedError(error: Error)
}

extension JSONError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongDataFormat(let error):
            return NSLocalizedString("Could not digest the fetched data. \(error.localizedDescription)", comment: "")
        case .missingData:
            return NSLocalizedString("Found and will discard a task missing a valid modality, file name, name, or instructions.", comment: "")
        case .batchInsertError:
            return NSLocalizedString("Failed to execute a batch insert request.", comment: "")
        case .unexpectedError(let error):
            return NSLocalizedString("Received unexpected error. \(error.localizedDescription)", comment: "")
        }
    }
}

extension JSONError: Identifiable {
    var id: String? {
        errorDescription
    }
}
