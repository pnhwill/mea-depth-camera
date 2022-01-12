//
//  ProcessingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit
import Combine

/// A UICollectionViewController subclass that displays all Recordings associated with the current Use Case, grouped by Task, for initiating post-processing and updating the user on its progress.
class ProcessingListViewController: UICollectionViewController {
    
    typealias Section = ProcessingListViewModel.Section
    typealias Item = ProcessingListViewModel.Item
    
    enum TrackingState {
        case tracking
        case stopped
    }
    
    private static let sectionHeaderElementKind = "SectionHeaderElementKind"
    
    private let visionTrackingQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("visionTrackingQueue"),
        qos: .userInitiated,
        autoreleaseFrequency: .workItem)
    
    @IBOutlet private weak var startStopButton: UIBarButtonItem!
    
    private var useCase: UseCase?
    private var viewModel: ProcessingListViewModel?
    private var dataSource: UICollectionViewDiffableDataSource<Section.ID, Item.ID>?
    private var trackingState: TrackingState = .stopped {
        didSet {
            self.handleTrackingStateChange()
        }
    }
    private var listItemsSubscriber: AnyCancellable?
    private var recordingDidChangeSubscriber: Cancellable?
    
    func configure(useCase: UseCase) {
        self.useCase = useCase
        viewModel = ProcessingListViewModel(useCase: useCase, processingCompleteAction: { [weak self] in
            DispatchQueue.main.async {
                self?.trackingState = .stopped
            }
        })
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Review Recordings"
        configureCollectionView()
        configureDataSource()
        refreshListData(isInitialSnapshot: true)
        
        listItemsSubscriber = viewModel?.sectionsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData(isInitialSnapshot: false)
            }
        recordingDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .recordingDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.recordingId] }
            .sink { [weak self] id in
                guard let recordingId = id as? UUID else { return }
                self?.reconfigureItem(recordingId)
            }
    }
    
    // MARK: Button Actions
    
    @IBAction func handleStartStopButton(_ sender: UIBarButtonItem) {
        // Disable button until it is safe to cancel
        startStopButton.isEnabled = false
        switch trackingState {
        case .tracking:
            // stop tracking
            viewModel?.cancelProcessing()
            trackingState = .stopped
        case .stopped:
            // initialize processor and start tracking
            trackingState = .tracking
            visionTrackingQueue.async {
                do {
                    try self.viewModel?.startProcessing()
                } catch {
                    self.handleError(error)
                }
            }
        }
        startStopButton.isEnabled = true
    }
}

// MARK: Face Landmarks Processing
extension ProcessingListViewController {
    private func handleTrackingStateChange() {
        switch trackingState {
        case .tracking:
            navigationItem.title = "Processing..."
            startStopButton.title = "Stop Processing"
            isModalInPresentation = true
        case .stopped:
            navigationItem.title = "Review Recordings"
            startStopButton.title = "Start Processing"
            isModalInPresentation = false
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            var messageHeader: String
            if error is VisionTrackerProcessorError {
                messageHeader = "Vision Processor Error"
            } else {
                messageHeader = "Error"
            }
            let message: String = messageHeader + ": " + error.localizedDescription
            let alertController = Alert.displayError(message: message, completion: nil)
            self.alert(alertController: alertController)
        }
    }
}

// MARK: Collection View Configuration
extension ProcessingListViewController {
    private func configureCollectionView() {
        collectionView.collectionViewLayout = createLayout()
    }
    
    // MARK: Layout
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout() { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.headerMode = .supplementary
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: Self.sectionHeaderElementKind, alignment: .top)
            section.boundarySupplementaryItems = [sectionHeader]
            return section
        }
    }
    
    // MARK: Data Source
    private func configureDataSource() {
        let headerRegistration = createHeaderRegistration()
        let cellRegistration = createCellRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section.ID, Item.ID>(collectionView: collectionView) {
            (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemID)
        }
        
        dataSource?.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
    
    // MARK: Snapshots
    private func refreshListData(isInitialSnapshot: Bool) {
        // Set the order for our sections
        guard let keys = viewModel?.sectionsStore?.allModels.keys else { return }
        let sections = Array(keys)
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, Item.ID>()
        snapshot.appendSections(sections)
        if !isInitialSnapshot {
            snapshot.reloadSections(sections)
        }
        dataSource?.apply(snapshot, animatingDifferences: !isInitialSnapshot)
        
        // Set section snapshots for each section
        for section in sections {
            guard let items = viewModel?.sectionsStore?.fetchByID(section)?.recordings else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: !isInitialSnapshot)
        }
    }
    
    private func reconfigureItem(_ itemID: Item.ID) {
        guard let dataSource = dataSource, dataSource.indexPath(for: itemID) != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([itemID])
        dataSource.apply(snapshot)
    }
}

// MARK: Cell Registration
extension ProcessingListViewController {
    
    private func createHeaderRegistration() -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell> {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: Self.sectionHeaderElementKind) {
            [weak self] (supplementaryView, elementKind, indexPath) in
            guard let sectionID = self?.dataSource?.snapshot().sectionIdentifiers[indexPath.section],
                  let section = self?.viewModel?.sectionsStore?.fetchByID(sectionID)
            else { return }
            
            supplementaryView.configurationUpdateHandler = { supplementaryView, state in
                guard let supplementaryCell = supplementaryView as? UICollectionViewListCell else { return }
                
                var contentConfiguration = UIListContentConfiguration.valueCell().updated(for: state)
                contentConfiguration.text = section.title
                contentConfiguration.secondaryText = section.processedRecordingsText
                supplementaryCell.contentConfiguration = contentConfiguration
            }
        }
    }
    
    private func createCellRegistration() -> UICollectionView.CellRegistration<ProcessingListCell, Item.ID> {
        return UICollectionView.CellRegistration<ProcessingListCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
}

