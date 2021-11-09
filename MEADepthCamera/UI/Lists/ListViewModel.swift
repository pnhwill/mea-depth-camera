//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit
import CoreData

protocol ListViewModel {
    
    typealias Item = ListItem
    typealias Section = ListSection
    
    var sectionsStore: ObservableModelStore<Section>? { get }
    var itemsStore: ObservableModelStore<Item>? { get }
    
}









// MARK: ListViewModel
protocol OldListViewModel {
    associatedtype ListCell: ItemListCell
    associatedtype HeaderCell: ItemListCell
    
    typealias Item = ListItem
    typealias Section = ListSection
    
    var dataSource: UICollectionViewDiffableDataSource<Section.ID, Item.ID>? { get set }
    var sectionsStore: ObservableModelStore<Section>? { get }
    var itemsStore: ObservableModelStore<Item>? { get }
    
    func configure(_ listCell: ListCell)
    func applyInitialSnapshots()
}

// MARK: applyInitialSnapshots()
extension OldListViewModel {
    func applyInitialSnapshots() {
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, Item.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for sectionID in sections {
            guard let items = sectionsStore?.fetchByID(sectionID)?.items else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: false)
        }
    }
    
    func applySnapshotFromListStore() {
        guard let items = sectionsStore?.fetchByID(.list)?.items else { return }
        var snapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
        snapshot.append(items)
        dataSource?.apply(snapshot, to: .list)
    }
}

// MARK: fetchedResultsController(didChange:at:for:newIndexPath:)
extension OldListViewModel {
    func fetchedResultsController(didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        print("\(#function) called from ListViewModel implementation")
        guard let item = anObject as? ModelObject,
              let itemID = item.id,
              var snapshot = dataSource?.snapshot()
        else { fatalError() }
        switch type {
        case .insert:
            print("INSERT")
            if let newIndexPath = newIndexPath,
               let destinationItemID = dataSource?.itemIdentifier(for: newIndexPath) {
                snapshot.insertItems([itemID], beforeItem: destinationItemID)
            } else {
                snapshot.appendItems([itemID], toSection: .list)
            }
        case .delete:
            print("DELETE")
            snapshot.deleteItems([itemID])
        case .move:
            print("MOVE")
            if let indexPath = indexPath,
               let newIndexPath = newIndexPath,
               let destinationItemID = dataSource?.itemIdentifier(for: newIndexPath) {
                let isAfter = newIndexPath > indexPath
                if isAfter {
                    snapshot.moveItem(itemID, afterItem: destinationItemID)
                } else {
                    snapshot.moveItem(itemID, beforeItem: destinationItemID)
                }
            }
        case .update:
            print("UPDATE")
            snapshot.reloadItems([itemID])
        @unknown default:
            break
        }
        dataSource?.apply(snapshot)
    }
}
