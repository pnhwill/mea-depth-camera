//
//  CodingMatrixFloat3.swift
//  MEADepthCamera
//
//  Created by Will on 10/13/21.
//

import Foundation

/// Helper class which can encode/decode any size SIMD matrix type with SIMD3 column vectors.
///
/// We use this class to serialize the AVCameraCalibrationData's intrinsicMatrix (matrix_float3x3) and extrinsicMatrix (matrix_float4x3).
/// The class stores a variable number of columns as type SIMD3<Float> (aka vector_float3) and encodes them as a single byte buffer in memory.
class CodingMatrixFloat3: NSObject, NSSecureCoding {

    static var supportsSecureCoding: Bool {
        return true
    }
    
    typealias Float3 = SIMD3<Float>
    
    private enum CodingKeys: String, CodingKey {
        case columns
    }
    
    var columns: [Float3] = []
    
    private let strideOfFloat3 = MemoryLayout<Float3>.stride
    
    init(_ columns: [Float3]) {
        self.columns = columns
    }
    
    required init?(coder: NSCoder) {
        super.init()
        // decodeBytesForKey() returns an UnsafePointer<UInt8>?, pointing to immutable data.
        var length = 0
        if let bytePointer = coder.decodeBytes(forKey: CodingKeys.columns.rawValue, returnedLength: &length) {
            // Convert it to a buffer pointer of the appropriate type and count and create the array.
            let numColumns = length / strideOfFloat3
            bytePointer.withMemoryRebound(to: Float3.self, capacity: numColumns) { pointer in
                let bufferPointer = UnsafeBufferPointer<Float3>(start: pointer, count: numColumns)
                self.columns = Array<Float3>(bufferPointer)
            }
        }
    }
    
    func encode(with coder: NSCoder) {
        // This encodes both the number of bytes and the data itself.
        let numBytes = columns.count * strideOfFloat3
        columns.withUnsafeBufferPointer { bufferPointer in
            bufferPointer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: numBytes) { pointer in
                coder.encodeBytes(pointer, length: numBytes, forKey: CodingKeys.columns.rawValue)
            }
        }
    }
}
