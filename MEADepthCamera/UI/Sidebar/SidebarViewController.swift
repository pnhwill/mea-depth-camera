//
//  SidebarViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import UIKit

/// A view controller for the app's top-level main menu, providing a starting point to reach every part of the app.
final class SidebarViewController: UICollectionViewController {
    
    typealias SidebarDiffableDataSource = UICollectionViewDiffableDataSource<SidebarSection, SidebarItem>
    
    private var mainSplitViewController: MainSplitViewController? {
        self.splitViewController as? MainSplitViewController
    }
    
    private var dataSource: SidebarDiffableDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = Bundle.main.applicationName
        configureCollectionView()
        configureDataSource()
        applySnapshots()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let mainSplitViewController = mainSplitViewController {
            clearsSelectionOnViewWillAppear = mainSplitViewController.isCollapsed
        }
        super.viewWillAppear(animated)
    }
}

// MARK: Collection View
extension SidebarViewController {
    
    typealias SidebarSnapshot = NSDiffableDataSourceSnapshot<SidebarSection, SidebarItem>
    
    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
            configuration.headerMode = .supplementary
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
        collectionView.collectionViewLayout = layout
    }
    
    private func configureDataSource() {
        let itemCellRegistration = createItemCellRegistration()
        let headerSupplementaryRegistration = createHeaderSupplementaryRegistration()
        
        dataSource = SidebarDiffableDataSource(collectionView: collectionView) {
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
        let sections = SidebarSection.allCases
        var snapshot = SidebarSnapshot()
        snapshot.appendSections(sections)
        
        for section in sections {
            snapshot.appendItems(section.items, toSection: section)
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
    
    private func selectItemIfNeeded() {
        guard let mainSplitViewController = mainSplitViewController,
              !mainSplitViewController.isCollapsed,
              let selectedList = mainSplitViewController.selectedList
        else { return }
        let indexPath = dataSource?.indexPath(for: selectedList)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
    }
}

// MARK: Cell Registrations
extension SidebarViewController {
    typealias SidebarItemCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarItem>
    typealias SidebarHeaderSupplementaryRegistration = UICollectionView.SupplementaryRegistration<ListHeaderSupplementaryView>
    
    private func createItemCellRegistration() -> SidebarItemCellRegistration {
        return SidebarItemCellRegistration { (cell, indexPath, item) in
            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.text = item.title
            cell.contentConfiguration = contentConfiguration
        }
    }
    
    private func createHeaderSupplementaryRegistration() -> SidebarHeaderSupplementaryRegistration {
        return SidebarHeaderSupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader) {
            [weak self] (supplementaryView, elementKind, indexPath) in
            guard let section = self?.dataSource?.sectionIdentifier(for: indexPath.section) else { return }
            supplementaryView.updateWithItem(ListHeaderViewModel(section))
        }
    }
}
    
// MARK: UICollectionViewDelegate
extension SidebarViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource?.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .useCases, .tasks:
            mainSplitViewController?.selectedList = item
        case .about:
            let aboutViewController: AboutViewController = UIStoryboard(storyboard: .info).instantiateViewController()
            let navigationController = UINavigationController(rootViewController: aboutViewController)
            present(navigationController, animated: true) { [weak self] in
                collectionView.deselectItem(at: indexPath, animated: true)
                self?.selectItemIfNeeded()
            }
        }
    }
}

