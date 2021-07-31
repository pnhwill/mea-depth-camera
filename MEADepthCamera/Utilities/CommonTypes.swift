//
//  CommonTypes.swift
//  MEADepthCamera
//
//  Created by Will on 7/30/21.
//

import Foundation

struct ProcessorSettings {
    let numLandmarks: Int = 76
    var videoResolution: CGSize = CGSize()
    var depthResolution: CGSize = CGSize()
    
    func getProperties() -> (Int, CGSize, CGSize) {
        return (numLandmarks, videoResolution, depthResolution)
    }
}
