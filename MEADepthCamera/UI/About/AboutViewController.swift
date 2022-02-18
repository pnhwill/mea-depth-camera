//
//  AboutViewController.swift
//  MEADepthCamera
//
//  Created by Will on 12/13/21.
//

import UIKit

/// OldListViewController subclass for the app's "About" view.
class AboutViewController: UICollectionViewController {
    
    typealias Section = AboutViewModel.AboutSection
    typealias Item = AboutViewModel.AboutItem
    typealias AboutDiffableDataSource = UICollectionViewDiffableDataSource<Section, Item>
    
    private lazy var viewModel: AboutViewModel = AboutViewModel()
    private var dataSource: AboutDiffableDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.allowsSelection = false
        title = viewModel.navigationTitle
        configureCollectionView()
        configureDataSource()
        applySnapshots()
    }
}

// MARK: Collection View
extension AboutViewController {
    
    typealias AboutSnapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            var configuration = UICollectionLayoutListConfiguration(appearance: .grouped)
            configuration.headerMode = .supplementary
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
        collectionView.collectionViewLayout = layout
    }
    
    private func configureDataSource() {
        let itemCellRegistration = createItemCellRegistration()
        let headerSupplementaryRegistration = createHeaderSupplementaryRegistration()
        
        dataSource = AboutDiffableDataSource(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell in
            return collectionView.dequeueConfiguredReusableCell(using: itemCellRegistration, for: indexPath, item: item)
        }
        
        dataSource?.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
            switch elementKind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerSupplementaryRegistration, for: indexPath)
            default:
                return nil
            }
        }
    }
    
    private func applySnapshots() {
        let sections = viewModel.aboutInfo.aboutSections
        var snapshot = AboutSnapshot()
        snapshot.appendSections(sections)
        for section in sections {
            snapshot.appendItems(section.items, toSection: section)
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: Cell Registrations
extension AboutViewController {
    
    typealias AboutItemCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item>
    typealias AboutHeaderSupplementaryRegistration = UICollectionView.SupplementaryRegistration<ListHeaderSupplementaryView>
    
    private func createItemCellRegistration() -> AboutItemCellRegistration {
        return AboutItemCellRegistration { (cell, indexPath, item) in
            var contentConfiguration = UIListContentConfiguration.valueCell()
            contentConfiguration.text = item.title
            contentConfiguration.secondaryText = item.subtitle
            cell.contentConfiguration = contentConfiguration
        }
    }
    
    private func createHeaderSupplementaryRegistration() -> AboutHeaderSupplementaryRegistration {
        return AboutHeaderSupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader) {
            [weak self] (supplementaryView, elementKind, indexPath) in
            guard let section = self?.dataSource?.sectionIdentifier(for: indexPath.section) else { return }
            supplementaryView.updateWithItem(ListHeaderViewModel(section))
        }
    }
}
