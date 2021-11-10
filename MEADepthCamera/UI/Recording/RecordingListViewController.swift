//
//  RecordingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListViewController: UICollectionViewController {
    
    typealias Section = RecordingListViewModel.Section
    typealias Item = RecordingListViewModel.Item
    
    private static let sectionHeaderElementKind = "SectionHeaderElementKind"
    
    private var useCase: UseCase?
    private var viewModel: RecordingListViewModel?
    private var dataSource: UICollectionViewDiffableDataSource<Section.ID, Item.ID>?
    
    func configure(useCase: UseCase) {
        self.useCase = useCase
        viewModel = RecordingListViewModel(useCase: useCase)
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshot()
    }
}

// MARK: Collection View Configuration
extension RecordingListViewController {
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
    private func applyInitialSnapshot() {
        // Set the order for our sections
        guard let keys = viewModel?.sectionsStore?.allModels.keys else { return }
        let sections = Array(keys)
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, Item.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for section in sections {
            guard let items = viewModel?.sectionsStore?.fetchByID(section)?.recordings else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: false)
        }
    }
}

// MARK: Cell Registration
extension RecordingListViewController {
    
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
    
    private func createCellRegistration() -> UICollectionView.CellRegistration<RecordingListCell, Item.ID> {
        return UICollectionView.CellRegistration<RecordingListCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
}










// MARK: - OLD
class OldRecordingListViewController: UITableViewController {
    
//    @IBOutlet private weak var useCaseView: UseCaseSummaryView!
    
    private var dataSource: RecordingListDataSource?
    private var useCase: UseCase?
    
    private weak var delegate: RecordingInteractionDelegate?
    
    // Post-Processing
    private var recordingsToTrack: [Int: Recording] = [:]
    private var faceLandmarksPipeline: FaceLandmarksPipeline?
    private var trackingState: TrackingState = .stopped {
        didSet {
            self.handleTrackingStateChange()
        }
    }
    let visionTrackingQueue = DispatchQueue(label: Bundle.main.reverseDNS(suffix: "visionTrackingQueue"), qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func configure(useCase: UseCase, task: Task, delegate: RecordingInteractionDelegate) {
        self.useCase = useCase
        self.delegate = delegate
        dataSource = RecordingListDataSource(useCase: useCase, task: task, recordingDeletedAction: {
            self.delegate?.didUpdateRecording(nil, shouldReloadRow: true)
        })
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = dataSource
        navigationItem.title = dataSource?.navigationTitle
        tableView.register(UINib(nibName: Self.processingHeaderNibName, bundle: nil), forHeaderFooterViewReuseIdentifier: Self.processingViewIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUseCaseView()
    }
    
    private func refreshUseCaseView() {
//        let titleText = [useCase?.experiment?.title, useCase?.title].compactMap { $0 }.joined(separator: ": ")
//        useCaseView.configure(title: titleText, subjectIDText: useCase?.subjectID)
    }
    
}

// MARK: UITableViewDelegate
extension OldRecordingListViewController {
    static let processingHeaderNibName = "ProcessingView"
    static let processingViewIdentifier = "ProcessingHeaderFooterView"
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 0
        default:
            return 55
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return nil
        default:
            guard let isProcessed = dataSource?.isRecordingProcessed(at: section), !isProcessed else { return nil }

//            guard let views = Bundle.main.loadNibNamed(Self.processingHeaderNibName, owner: self, options: nil),
//                  let processingHeaderView = views[0] as? ProcessingView else { return nil }

            guard let processingView = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.processingViewIdentifier) as? ProcessingView else { return nil }
            
            processingView.section = section
            
            let displayText = "Tap to Start Processing"
            processingView.configure(isProcessing: false, frameCounterText: displayText, progress: nil, startStopAction: { section in
                self.handleStartStopButton(in: section)
            })
            return processingView
        }
    }
}

// MARK: Face Landmarks Processing
extension OldRecordingListViewController {
    
    private func handleStartStopButton(in section: Int) {
        switch trackingState {
        case .tracking(let index):
            if index == section {
                // Stop tracking
                self.faceLandmarksPipeline?.cancelTracking()
                self.trackingState = .stopped
            } else {
                var displayText = "Waiting..."
                if let _ = recordingsToTrack[section] {
                    recordingsToTrack.removeValue(forKey: section)
                    displayText = "Tap to Start Processing"
                } else {
                    guard let recording = dataSource?.recording(at: section) else {
                        print("Failed to start tracking: recording not found")
                        return
                    }
                    recordingsToTrack[section] = recording
                }
                guard let processingView = tableView.footerView(forSection: section) as? ProcessingView else { return }
                processingView.configure(isProcessing: false, frameCounterText: displayText, progress: nil, startStopAction: { section in
                    self.handleStartStopButton(in: section)
                })
            }
        case .stopped:
            // Initialize processor and start tracking
            self.trackingState = .tracking(section)
            guard let recording = dataSource?.recording(at: section) else {
                print("Failed to start tracking: recording not found")
                return
            }
            recordingsToTrack[section] = recording
            visionTrackingQueue.async {
                self.startTracking(recording)
            }
        }
    }
    
    private func startTracking(_ recording: Recording) {
        guard let processorSettings = recording.processorSettings else {
            print("Failed to start tracking: processor settings not found")
            return
        }
        faceLandmarksPipeline = FaceLandmarksPipeline(recording: recording, processorSettings: processorSettings)
        faceLandmarksPipeline?.delegate = self
        do {
            try faceLandmarksPipeline?.startTracking()
        } catch {
            self.handleTrackerError(error)
        }
    }
    
    private func handleTrackerError(_ error: Error) {
        DispatchQueue.main.async {
            var messageHeader: String
            if error is VisionTrackerProcessorError {
                messageHeader = "Vision Processor Error"
            } else {
                messageHeader = "Error"
            }
            let message: String = messageHeader + ": " + error.localizedDescription
            let actions = [UIAlertAction(title: "OK", style: .cancel, handler: nil)]
            self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
        }
    }
    
    private func handleTrackingStateChange() {
         //disable navigation from page
         //start tracking next in queue
        switch trackingState {
        case .tracking(let index):
            guard let processingView = tableView.footerView(forSection: index) as? ProcessingView else { break }
            let displayText = "Analyzing..."
            processingView.configure(isProcessing: true, frameCounterText: displayText, progress: nil, startStopAction: { section in
                self.handleStartStopButton(in: section)
            })
        case .stopped:
            if !recordingsToTrack.isEmpty {
                guard let nextRecording = recordingsToTrack.first else { break }
                self.trackingState = .tracking(nextRecording.key)
                visionTrackingQueue.async {
                    self.startTracking(nextRecording.value)
                }
            }
        }
        self.tableView.reloadData()
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

// MARK: FaceLandmarksPipelineDelegate
extension OldRecordingListViewController: FaceLandmarksPipelineDelegate {
    func displayFrameCounter(_ frame: Int, totalFrames: Int) {
        switch trackingState {
        case .tracking(let index):
            guard let processingView = tableView.footerView(forSection: index) as? ProcessingView else { return }
            let displayText = "Frame: \(frame)/\(totalFrames)"
            let progress = Float(frame) / Float(totalFrames)
            processingView.configure(isProcessing: true, frameCounterText: displayText, progress: progress, startStopAction: { section in
                self.handleStartStopButton(in: section)
            })
        case .stopped:
            return
        }
    }
    
    func didFinishTracking(success: Bool) {
        switch trackingState {
        case .tracking(let index):
            guard let recording = recordingsToTrack[index] else { return }

            let context = recording.managedObjectContext
            let container = dataSource?.dataProvider.persistentContainer
            if success {
                // save the recording to persistent storage
                recording.isProcessed = true
                container?.saveContext(backgroundContext: context)
            } else {
                context?.rollback()
            }
            container?.viewContext.refresh(recording, mergeChanges: true)
            // remove recording from tracking waiting list
            recordingsToTrack.removeValue(forKey: index)
            
            DispatchQueue.main.async {
                self.trackingState = .stopped
            }
        case .stopped:
            return
        }
    }
}
