//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

/// A view controller for the app's top-level menu, providing a starting point to reach every part of the app.
class MainMenuViewController: UICollectionViewController {
    
    typealias Section = MainMenuViewModel.Section
    typealias Item = MainMenuViewModel.Item
    
    private struct ElementKind {
        static let titleHeader = "TitleHeader"
    }
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private var mainSplitViewController: OldMainSplitViewController? {
        self.splitViewController as? OldMainSplitViewController
    }
    
    deinit {
        print("MainMenuViewController deinitialized.")
    }
    
    func useCaseListButtonTapped(_ sender: UIButton) {
        mainSplitViewController?.transitionToUseCaseList()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
        configureCollectionView()
        configureDataSource()
        applySnapshots()
    }
}

extension MainMenuViewController {
    
    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
            configuration.headerMode = .firstItemInSection
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            if sectionIndex == 0 {
                let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .absolute(200))
                let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: titleSize,
                    elementKind: ElementKind.titleHeader,
                    alignment: .top)
                section.boundarySupplementaryItems = [titleSupplementary]
            }
            return section
        }
        collectionView.collectionViewLayout = layout
    }
    
    private func configureDataSource() {
        let itemCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
            (cell, indexPath, item) in
            
            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.text = item.title
            
            cell.contentConfiguration = contentConfiguration
        }
        
        let expandableSectionHeaderRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
            (cell, indexPath, item) in
            
            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.text = item.title
            
            cell.contentConfiguration = contentConfiguration
            cell.accessories = [.outlineDisclosure()]
        }
        
        let titleSupplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: ElementKind.titleHeader) {
            (supplementaryView, elementKind, indexPath) in
            supplementaryView.label.text = "MEADepthCamera"
            supplementaryView.label.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell in
            
            switch item.type {
            case .expandableHeader:
                return collectionView.dequeueConfiguredReusableCell(using: expandableSectionHeaderRegistration, for: indexPath, item: item)
            default:
                return collectionView.dequeueConfiguredReusableCell(using: itemCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
            return collectionView.dequeueConfiguredReusableSupplementary(using: titleSupplementaryRegistration, for: indexPath)
        }
    }
    
    private func applySnapshots() {
        let sections = Section.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        for section in sections {
            let headerItem = section.headerItem
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
            sectionSnapshot.append([headerItem])
            sectionSnapshot.expand([headerItem])
            sectionSnapshot.append(section.subItems, to: headerItem)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: false)
        }
    }
}

// MARK: UICollectionViewDelegate
extension MainMenuViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch MainMenuViewModel.StandardItem(rawValue: item.title) {
        case .useCases:
            mainSplitViewController?.transitionToUseCaseList()
        case .tasks:
            mainSplitViewController?.transitionToTaskList()
        case .about:
            let storyboard = UIStoryboard(name: StoryboardName.main, bundle: nil)
            let aboutViewController = storyboard.instantiateViewController(withIdentifier: StoryboardID.aboutViewController)
            present(aboutViewController, animated: true, completion: nil)
        default: return
        }
    }
}
