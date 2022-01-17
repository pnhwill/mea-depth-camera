//
//  MainMenuViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/17/22.
//

import Foundation

/// View model for the main menu collection view.
class MainMenuViewModel {
    
    // MARK: Section
    
    enum Section: Int, CaseIterable {
        case main
        case info
        
        var headerItem: Item {
            Item(title: headerTitle, type: .expandableHeader)
        }
        
        var subItems: [Item] {
            standardItems.map { $0.item }
        }
        
        private var standardItems: [StandardItem] {
            switch self {
            case .main:
                return [.useCases]
            case .info:
                return [.about]
            }
        }
        
        private var headerTitle: String {
            switch self {
            case .main:
                return "Plan & Perform"
            case .info:
                return "Info"
            }
        }
    }
    
    // MARK: Item
    
    enum StandardItem: String {
        case useCases = "Use Cases"
        case about = "About"
        
        var item: Item {
            Item(title: rawValue, type: .standard)
        }
    }
    
    struct Item: Hashable {
        let title: String
        let type: ItemType
        
        enum ItemType {
            case standard, expandableHeader
        }
    }
    
}
