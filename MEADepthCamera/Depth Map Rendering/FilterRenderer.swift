//
//  FilterRenderer.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Filter renderer protocol.
*/

import CoreMedia

protocol FilterRenderer: AnyObject {
    
    var description: String { get }
    
    var isPrepared: Bool { get }
    
    // Prepare resources.
    // The outputRetainedBufferCountHint tells out of place renderers how many of
    // their output buffers will be held onto by the downstream pipeline at one time.
    // This can be used by the renderer to size and preallocate their pools.
    func prepare(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int)
    
    // Release resources.
    func reset()
    
    // The format description of the output pixel buffers.
    var outputFormatDescription: CMFormatDescription? { get }
    
    // The format description of the input pixel buffers.
    var inputFormatDescription: CMFormatDescription? { get }
    
    // Render pixel buffer.
    func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer?
}
