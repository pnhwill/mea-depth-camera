//
//  DetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/25/21.
//

import UIKit

protocol DetailViewModel {
    associatedtype Section: Identifiable
    associatedtype Item: Identifiable
    
    var sectionsStore: AnyModelStore<Section>? { get }
    var itemsStore: AnyModelStore<Item>? { get }
}

