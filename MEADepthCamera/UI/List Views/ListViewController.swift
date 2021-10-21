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
class ListViewController<ViewModel: ListViewModel>: UIViewController, UICollectionViewDelegate {
    
    typealias ListDiffableDataSource = UICollectionViewDiffableDataSource<Section.ID, Item.ID>
    
    var viewModel: ViewModel?
    
    private var collectionView: UICollectionView!
    private var dataSource: ListDiffableDataSource?
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureDataSource()
        applyInitialSnapshots()
    }
}

extension ListViewController {
    private func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            let section: NSCollectionLayoutSection
            
            switch sectionID {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .fractionalHeight(1.0))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                               subitems: [item])
                group.interItemSpacing = .flexible(10)
                section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                
            case .list:
                let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
                section = NSCollectionLayoutSection.list(using: configuration,
                                                         layoutEnvironment: layoutEnvironment)
            }
            
            return section
        }
        
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = 20
        
        return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider,
                                                   configuration: configuration)
    }
    
    private func configureDataSource() {
        let headerCellRegistration = createHeaderCellRegistration()
        let listCellRegistration = createListCellRegistration()
        
        dataSource = ListDiffableDataSource(collectionView: collectionView) {
            (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            guard let sectionID = Section.ID(rawValue: indexPath.section) else { return nil }
            
            switch sectionID {
            case .header:
                return collectionView.dequeueConfiguredReusableCell(using: headerCellRegistration, for: indexPath, item: itemID)
            case .list:
                return collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: itemID)
            }
        }
    }
    
    private func applyInitialSnapshots() {
        
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, Item.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for sectionID in sections {
            guard let items = viewModel?.sectionsStore?.fetchByID(sectionID)?.items else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: false)
        }
    }
    
    private func createListCellRegistration() -> UICollectionView.CellRegistration<ViewModel.ListCell, Item.ID> {
        return UICollectionView.CellRegistration<ViewModel.ListCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
//    private func createListCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> {
//        return UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
//            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
//
//            var content = cell.defaultContentConfiguration()
//            content.text = item.object.id?.uuidString
//            cell.contentConfiguration = content
//
////            cell.updateWithItem(item)
//        }
//    }
    
    private func createHeaderCellRegistration() -> UICollectionView.CellRegistration<ViewModel.HeaderCell, Item.ID> {
        return UICollectionView.CellRegistration<ViewModel.HeaderCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
}

// MARK: UICollectionViewDelegate
extension ListViewController {
    
}


