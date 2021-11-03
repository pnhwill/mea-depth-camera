//
//  UseCaseDetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class UseCaseDetailViewModel: DetailViewModel {
    
    enum Section: Int, CaseIterable {
        case info
    }
    
    enum Item: Int, CaseIterable {
        case title
        case experiment
        case subjectID
        case date
        case completedTasks
        case notes
        
        static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()
        
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateStyle = .long
            return formatter
        }()
        
        var cellImage: UIImage? {
            switch self {
            case .title:
                return nil
            case .experiment:
                return UIImage(systemName: "chart.bar.xaxis")
            case .date:
                return UIImage(systemName: "calendar.circle")
            case .subjectID:
                return UIImage(systemName: "person.fill.viewfinder")
            case .completedTasks:
                return UIImage(systemName: "tray.full")
            case .notes:
                return UIImage(systemName: "square.and.pencil")
            }
        }
        
        func displayText(for useCase: UseCase) -> String? {
            switch self {
            case .title:
                return useCase.title
            case .experiment:
                return useCase.experiment?.title
            case .date:
                guard let date = useCase.date else { return nil }
                let timeText = Self.timeFormatter.string(from: date)
                if Locale.current.calendar.isDateInToday(date) {
                    return UseCase.todayDateFormatter.string(from: date)
                }
                return Self.dateFormatter.string(from: date) + " at " + timeText
            case .subjectID:
                guard let subjectID = useCase.subjectID else { return nil }
                return "Subject ID: " + subjectID
            case .completedTasks:
                return "X out of X tasks completed"
            case .notes:
                return useCase.notes
            }
        }
    }
    
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    private var useCase: UseCase
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    // MARK: Configure Collection View
    func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .firstItemInSection
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        
        let headerRegistration = createHeaderRegistration()
        let cellRegistration = createCellRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            
            if indexPath.item == 0 {
                return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
            } else {
                return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
            }
        }
    }
    
    func applyInitialSnapshots() {
        // Set the order for our sections
        let sections = Section.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for section in sections {
            let items = Item.allCases
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: false)
        }
    }
}

// MARK: Cell Registration
extension UseCaseDetailViewModel {
    private func createHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            content.text = item.displayText(for: self.useCase)
            cell.contentConfiguration = content
        }
    }
    
    private func createCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = item.displayText(for: self.useCase)
            content.image = item.cellImage
            cell.contentConfiguration = content
        }
    }
}
