//
//  Foundation+Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import Foundation

// MARK: Bundle
extension Bundle {
    /// Use bundle name instead of hard-coding app name in alerts.
    var applicationName: String {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return name
        } else if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return "MEADepthCamera"
    }
    
    func reverseDNS(_ suffix: String? = nil) -> String {
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


