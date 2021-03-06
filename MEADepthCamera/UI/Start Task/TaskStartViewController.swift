//
//  TaskStartViewController.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import UIKit

/// A detail view controller for viewing a Task's instructions and previously captured recordings.
class TaskStartViewController: UICollectionViewController {
    
    typealias Section = TaskStartViewModel.Section
    
    private struct ElementKind {
        static let recordingsSectionHeader = "RecordingsSectionHeader"
        static let infoSectionFooter = "StartButtonFooter"
    }
    
    private var viewModel: TaskStartViewModel?
    private var dataSource: UICollectionViewDiffableDataSource<Section.ID, DetailItem.ID>?
    private var useCase: UseCase?
    private var task: Task?
    
    func configure(with task: Task, useCase: UseCase) {
        self.task = task
        self.useCase = useCase
        self.viewModel = TaskStartViewModel(task: task, useCase: useCase)
        configureDataSource()
        applyInitialSnapshot()
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "View Task"
        configureCollectionView()
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        navigationItem.setHidesBackButton(!mainSplitViewController.isCollapsed, animated: false)
//    }
    
    @IBAction func useCaseButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

extension TaskStartViewController {
    func startButtonTapped() {
        guard let task = task, let useCase = useCase else { return }
        let storyboard = UIStoryboard(name: StoryboardName.camera, bundle: nil)
        guard let cameraViewController = storyboard.instantiateViewController(withIdentifier: StoryboardID.cameraViewController) as? CameraViewController
        else { return }
        cameraViewController.configure(useCase: useCase, task: task)
        show(cameraViewController, sender: nil)
    }
}

// MARK: Collection View Configuration
extension TaskStartViewController {
    private func configureCollectionView() {
        collectionView.collectionViewLayout = createLayout()
    }
    
    // MARK: Layout
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout() { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            switch sectionID {
            case .info:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .firstItemInSection
                config.footerMode = .supplementary
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
                let sectionFooter = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: footerSize, elementKind: ElementKind.infoSectionFooter, alignment: .bottom)
                section.boundarySupplementaryItems = [sectionFooter]
                return section
            case .recordings:
                var config = UICollectionLayoutListConfiguration(appearance: .plain)
                config.headerMode = .supplementary
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
                let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: ElementKind.recordingsSectionHeader, alignment: .top)
                section.boundarySupplementaryItems = [sectionHeader]
                return section
            }
        }
    }
    
    // MARK: Data Source
    private func configureDataSource() {
        let infoCellRegistration = createInfoCellRegistration()
        let infoFooterRegistration = createInfoFooterRegistration()
        let recordingCellRegistration = createRecordingCellRegistration()
        let recordingHeaderRegistration = createRecordingHeaderRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section.ID, DetailItem.ID>(collectionView: collectionView) {
            (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            guard let section = Section.ID(rawValue: indexPath.section) else { return nil }
            
            switch section {
            case .info:
                return collectionView.dequeueConfiguredReusableCell(using: infoCellRegistration, for: indexPath, item: itemID)
            case .recordings:
                return collectionView.dequeueConfiguredReusableCell(using: recordingCellRegistration, for: indexPath, item: itemID)
            }
        }
        
        dataSource?.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
            guard let section = Section.ID(rawValue: indexPath.section) else { return nil }
            switch section {
            case .info:
                return collectionView.dequeueConfiguredReusableSupplementary(using: infoFooterRegistration, for: indexPath)
            case .recordings:
                return collectionView.dequeueConfiguredReusableSupplementary(using: recordingHeaderRegistration, for: indexPath)
            }
        }
    }
    
    // MARK: Snapshots
    private func applyInitialSnapshot() {
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, DetailItem.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for section in sections {
            guard let items = viewModel?.sectionsStore?.fetchByID(section)?.items else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<DetailItem.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: false)
        }
    }
}

// MARK: Cell Registration
extension TaskStartViewController {
    
    private func createInfoCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            var content = indexPath.item == 0 ? UIListContentConfiguration.extraProminentInsetGroupedHeader() : cell.defaultContentConfiguration()
            content.text = item.title
            content.image = item.image
            cell.contentConfiguration = content
        }
    }
    
    private func createInfoFooterRegistration() -> UICollectionView.SupplementaryRegistration<ButtonSupplementaryView> {
        return UICollectionView.SupplementaryRegistration<ButtonSupplementaryView>(elementKind: ElementKind.infoSectionFooter) {
            [weak self] (supplementaryView, elementKind, indexPath) in
            supplementaryView.setButtonAction() {
                self?.startButtonTapped()
            }
        }
    }
    
    private func createRecordingCellRegistration() -> UICollectionView.CellRegistration<ListTextCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<ListTextCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            let cellModel = ListTextCellModel(detailItem: item)
            cell.updateWithItem(cellModel)
        }
    }
    
    private func createRecordingHeaderRegistration() -> UICollectionView.SupplementaryRegistration<TitleSupplementaryView> {
        return UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: ElementKind.recordingsSectionHeader) {
            (supplementaryView, elementKind, indexPath) in
            let defaultConfig = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            supplementaryView.label.text = "Recordings"
            supplementaryView.label.font = defaultConfig.textProperties.font
        }
    }
}


