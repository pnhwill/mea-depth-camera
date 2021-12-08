//
//  Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation
import UIKit

// MARK: Array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: UIView
extension UIView {
    func bindEdgesToSuperview() {
        
        guard let s = superview else {
            preconditionFailure("`superview` nil in bindEdgesToSuperview")
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: s.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: s.bottomAnchor).isActive = true
    }
}

// MARK: UIFont
extension UIFont {
    
    var bold: UIFont {
        return with(.traitBold)
    }

    var italic: UIFont {
        return with(.traitItalic)
    }

    var boldItalic: UIFont {
        return with([.traitBold, .traitItalic])
    }
    
    func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(self.fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    func without(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(self.fontDescriptor.symbolicTraits.subtracting(UIFontDescriptor.SymbolicTraits(traits))) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

// MARK: UIViewController
extension UIViewController {
    func alert(title: String, message: String, actions: [UIAlertAction]) {
        
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        
        actions.forEach {
            alertController.addAction($0)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: Bundle
extension Bundle {
    // Use bundle name instead of hard-coding app name in alerts
    var applicationName: String {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return name
        } else if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return "-"
    }
    
    func reverseDNS(suffix: String? = nil) -> String {
        var reverseDNS = Bundle.main.bundleIdentifier ?? "com.mea-lab.MEADepthCamera"
        if let suffix = suffix {
            reverseDNS += ".\(suffix)"
        }
        return reverseDNS
    }
}

// MARK: ProcessInfo.ThermalState
extension ProcessInfo.ThermalState {
    var thermalStateString: String {
        let state = self
        var thermalStateString = "UNKNOWN"
        if state == .nominal {
            thermalStateString = "NOMINAL"
        } else if state == .fair {
            thermalStateString = "FAIR"
        } else if state == .serious {
            thermalStateString = "SERIOUS"
        } else if state == .critical {
            thermalStateString = "CRITICAL"
        }
        return thermalStateString
    }
}


