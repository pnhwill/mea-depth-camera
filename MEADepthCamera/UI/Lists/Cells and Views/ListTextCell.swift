//
//  ListTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 1/21/22.
//

import UIKit

class ListTextCell: ItemListCell<ListItem> {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListItem else { return }
        var content = defaultContentConfiguration().updated(for: state)
        content.text = item.title
        content.secondaryText = item.subtitle
        contentConfiguration = content
    }
}

//struct ListTextCellModel: Hashable, ListCellModel {
//    var title: String
//    var subTitle: String
//
//    init(listItem: ListItem) {
//        title = listItem.title
//        subTitle = listItem.subtitle ?? ""
//    }
//}
//
//class ListTextCell: ItemListCell<ListTextCellModel> {
//
//    override func updateConfiguration(using state: UICellConfigurationState) {
//        guard let item = state.item as? ListTextCellModel else { return }
//        var content = defaultContentConfiguration().updated(for: state)
//        content.text = item.title
//        content.secondaryText = item.subTitle
//        contentConfiguration = content
//    }
//}
