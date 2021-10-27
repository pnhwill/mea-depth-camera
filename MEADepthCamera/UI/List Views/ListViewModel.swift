//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit
import CoreData

// MARK: ListViewModel
protocol ListViewModel {
    associatedtype ListCell: ItemListCell
    associatedtype HeaderCell: ItemListCell
    
    var dataSource: UICollectionViewDiffableDataSource<ListSection.ID, ListItem.ID>? { get set }
    var sectionsStore: AnyModelStore<ListSection>? { get }
    var itemsStore: AnyModelStore<ListItem>? { get }
    
    func applyInitialSnapshots()
}

// MARK: ListSection
struct ListSection: Identifiable {
    enum Identifier: Int, CaseIterable {
        case header
        case list
    }
    
    var id: Identifier
    var items: [ListItem.ID]?
}

// MARK: ListItem
/// A generic model of an item contained in a list cell, providing value semantics and erasing the underlying type of the stored object.
struct ListItem: Identifiable, Hashable {
    var id: UUID
    var object: ModelObject
    
    init?(object: ModelObject) {
        guard let id = object.id else { return nil }
        self.object = object
        self.id = id
    }
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: applyInitialSnapshots()
extension ListViewModel {
    func applyInitialSnapshots() {
        // Set the order for our sections
        let sections = ListSection.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<ListSection.ID, ListItem.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for sectionID in sections {
            guard let items = sectionsStore?.fetchByID(sectionID)?.items else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<ListItem.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: false)
        }
    }
}

// MARK: fetchedResultsController(didChange:at:for:newIndexPath:)
extension ListViewModel {
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
