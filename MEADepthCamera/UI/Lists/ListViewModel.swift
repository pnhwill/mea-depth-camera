//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit
import CoreData

/// Protocol for ListViewController view models.
protocol ListViewModel {
    
    typealias Item = ListItem
    typealias Section = ListSection
    
    var sectionsStore: ObservableModelStore<Section>? { get }
    var itemsStore: ObservableModelStore<Item>? { get }
    
}
