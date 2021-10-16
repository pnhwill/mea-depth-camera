//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import Foundation
import UIKit

protocol ListViewModel: UISearchResultsUpdating {
    
    var navigationTitle: String { get set }
    
    var sectionsStore: AnyModelStore<Section>? { get }
    var itemsStore: AnyModelStore<Item>? { get }
    
}

