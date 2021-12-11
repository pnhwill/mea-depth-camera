//
//  NotificationName.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//
/*
 Abstract:
 An extension that declares app-specific notification names.
 */

import Foundation

extension NSNotification.Name {
    static let useCaseDidChange = Notification.Name(Bundle.main.reverseDNS("useCaseDidChange"))
    static let recordingDidChange = Notification.Name(Bundle.main.reverseDNS("recordingDidChange"))
}

/// Custom keys to use with userInfo dictionaries.
enum NotificationKeys: String {
    case useCaseId
    case recordingId
}
