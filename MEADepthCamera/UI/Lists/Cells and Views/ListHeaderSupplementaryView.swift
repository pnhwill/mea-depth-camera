//
//  ListHeaderSupplementaryView.swift
//  MEADepthCamera
//
//  Created by Will on 1/26/22.
//

import UIKit

struct ListHeaderViewModel: Hashable {
    let title: String
    
    init(_ sidebarSection: SidebarSection) {
        self.title = sidebarSection.title
    }
    
    init(_ listSection: ListSection) {
        self.title = listSection.id
    }
}

class ListHeaderSupplementaryView: ItemListCell<ListHeaderViewModel> {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListHeaderViewModel else { return }
        var content = defaultContentConfiguration().updated(for: state)
        content.text = item.title
        contentConfiguration = content
    }
    
}
