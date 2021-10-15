//
//  ListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit
import CoreData

protocol ListViewControllerProtocol {
    
}

/// Base class for UIViewControllers that list object data from the Core Data model and present a detail view for selected cells.
class ListViewController: UIViewController {
    
    typealias ListDataSource = UICollectionViewDiffableDataSource<Section.ID, Item.ID>
    
    static let mainStoryboardName = "Main"
    
    struct Section: Identifiable {
        
        enum Identifier: Int {
            case header
            case list
            
            var appearance: UICollectionLayoutListConfiguration.Appearance {
                switch self {
                case .header:
                    return .insetGrouped
                case .list:
                    return .grouped
                }
            }
        }
        
        var id: Identifier
        var items: [Item]?
    }
    
    struct Item: Identifiable {
        var id: UUID
        var object: NSManagedObject
    }
    
    private var collectionView: UICollectionView!
    private var dataSource: ListDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}

extension ListViewController {
    private func configureHierarchy() {
        
    }
    
    private func createLayout() {
        let sectionProvider = { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            
            let configuration = UICollectionLayoutListConfiguration(appearance: sectionID.appearance)
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
    }
    
    
}
