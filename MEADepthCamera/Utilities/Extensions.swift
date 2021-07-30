//
//  Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation
import UIKit

extension CGFloat {
    func radiansForDegrees(/*_ degrees: CGFloat*/) -> CGFloat {
        return CGFloat(Double(self) * Double.pi / 180.0)
    }
}

extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}
