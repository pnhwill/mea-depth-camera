//
//  SidebarViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import Foundation

/// View model for the sidebar main menu sections.
enum SidebarSection: CaseIterable {
    case main
    case info
    
    var title: String {
        switch self {
        case .main:
            return "Main Menu"
        case .info:
            return "Info"
        }
    }
    
    var items: [SidebarItem] {
        switch self {
        case .main:
            return [.useCases, .tasks]
        case .info:
            return [.about]
        }
    }
}

/// View model for the sidebar main menu items.
enum SidebarItem: CaseIterable {
    case useCases
    case tasks
    case about
    
    var title: String {
        switch self {
        case .useCases:
            return "Use Cases"
        case .tasks:
            return "Tasks"
        case .about:
            return "About"
        }
    }
}
