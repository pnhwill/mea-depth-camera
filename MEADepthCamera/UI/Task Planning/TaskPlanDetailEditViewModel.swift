//
//  TaskPlanDetailEditViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/17/22.
//

import UIKit
import CoreData

/// The view model for TaskDetailViewController when it is in edit mode.
class TaskPlanDetailEditViewModel: NSObject, DetailViewModel {
    
    enum Section: Int, CaseIterable {
        case name
        case fileNameLabel
        case instructions
        
        var displayText: String {
            switch self {
            case .name:
                return "Name"
            case .fileNameLabel:
                return "File Name Label"
            case .instructions:
                return "Instructions"
            }
        }
    }
    
    struct Item: Hashable {
        enum ItemType: Int, CaseIterable {
            case header
            case input
        }
        let type: ItemType
        private let identifier = UUID()
    }
    
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    private var task: Task
    private var isNew: Bool
    
    init(task: Task, isNew: Bool) {
        self.task = task
        self.isNew = isNew
    }
    
    // MARK: Configure Collection View
    func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .firstItemInSection
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        
        let headerRegistration = createHeaderRegistration()
        let nameRegistration = createNameCellRegistration()
        let fileNameLabelRegistration = createFileNameLabelCellRegistration()
        let instructionsRegistration = createInstructionsCellRegistration()

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            
            if indexPath.item == 0 {
                return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
            } else {
                guard let section = Section(rawValue: indexPath.section) else { return nil }
                switch section {
                case .name:
                    return collectionView.dequeueConfiguredReusableCell(using: nameRegistration, for: indexPath, item: item)
                case .fileNameLabel:
                    return collectionView.dequeueConfiguredReusableCell(using: fileNameLabelRegistration, for: indexPath, item: item)
                case .instructions:
                    return collectionView.dequeueConfiguredReusableCell(using: instructionsRegistration, for: indexPath, item: item)
                }
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
            let items = Item.ItemType.allCases.map({ Item(type: $0) })
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
            sectionSnapshot.append(items)
            dataSource?.apply(sectionSnapshot, to: section, animatingDifferences: false)
        }
    }
}

// MARK: Cell Registration
extension TaskPlanDetailEditViewModel {
    private func createHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { (cell, indexPath, item) in
            guard let section = Section(rawValue: indexPath.section) else { return }
            var content = UIListContentConfiguration.groupedHeader()
            content.text = section.displayText
            cell.contentConfiguration = content
        }
    }
    private func createNameCellRegistration() -> UICollectionView.CellRegistration<TextFieldCell, Item> {
        return UICollectionView.CellRegistration<TextFieldCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.task.name, at: indexPath, delegate: self)
            cell.textField.autocapitalizationType = .words
            cell.textField.autocorrectionType = .no
            cell.textField.clearsOnBeginEditing = self.isNew
        }
    }
    private func createFileNameLabelCellRegistration() -> UICollectionView.CellRegistration<TextFieldCell, Item> {
        return UICollectionView.CellRegistration<TextFieldCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.task.fileNameLabel, at: indexPath, delegate: self)
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
            cell.textField.smartDashesType = .no
            cell.textField.smartQuotesType = .no
            cell.textField.smartInsertDeleteType = .no
            cell.textField.spellCheckingType = .no
        }
    }
    private func createInstructionsCellRegistration() -> UICollectionView.CellRegistration<TextViewCell, Item> {
        return UICollectionView.CellRegistration<TextViewCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.task.instructions, at: indexPath, delegate: self)
        }
    }
}

// MARK: TextInputCellDelegate
extension TaskPlanDetailEditViewModel: TextInputCellDelegate {
    func textChangedAt(indexPath: IndexPath, replacementString string: String) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .name:
            task.name = string
        case .fileNameLabel:
            task.fileNameLabel = string
        case .instructions:
            task.instructions = string
        }
    }
}

