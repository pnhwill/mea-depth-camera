//
//  UseCaseDetailEditViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

/// The view model for UseCaseDetailViewController when it is in edit mode.
class UseCaseDetailEditViewModel: NSObject, DetailViewModel {
    
    enum Section: Int, CaseIterable {
        case title
        case experiment
        case subjectID
        case notes
        
        var displayText: String {
            switch self {
            case .title:
                return "Title"
            case .experiment:
                return "Experiment"
            case .subjectID:
                return "Subject ID"
            case .notes:
                return "Notes"
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
    
    var navigationTitle: String {
        isNew ? NSLocalizedString("Add Use Case", comment: "add use case nav title") : NSLocalizedString("Edit Use Case", comment: "edit use case nav title")
    }
    
    private var useCase: UseCase
    private var isNew: Bool
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    private lazy var experimentProvider: ExperimentProvider = ExperimentProvider()
    
    private var experiments: [Experiment]? {
        return experimentProvider.fetchedResultsController.fetchedObjects
    }
    
    init(useCase: UseCase, isNew: Bool) {
        self.useCase = useCase
        self.isNew = isNew
    }
    
    func validateInput(title: String?, subjectID: String?) -> Bool {
        guard let title = title, let subjectID = subjectID else { return false }
        return !title.isEmpty && !subjectID.isEmpty
    }
    
    func save(completion: ((Bool) -> Void)? = nil) {
        let contextSaveInfo: ContextSaveContextualInfo = isNew ? .addUseCase : .updateUseCase
        AppDelegate.shared.coreDataStack.persistentContainer.saveContext(
            backgroundContext: useCase.managedObjectContext,
            with: contextSaveInfo) { success in
                completion?(success)
        }
    }
    
    // MARK: DetailViewModel
    
    func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .firstItemInSection
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        
        let headerRegistration = createHeaderRegistration()
        let titleRegistration = createTitleCellRegistration()
        let subjectIDRegistration = createSubjectIDCellRegistration()
        let experimentRegistration = createExperimentCellRegistration()
        let notesRegistration = createNotesCellRegistration()

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            
            if indexPath.item == 0 {
                return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
            } else {
                guard let section = Section(rawValue: indexPath.section) else { return nil }
                switch section {
                case .title:
                    return collectionView.dequeueConfiguredReusableCell(using: titleRegistration, for: indexPath, item: item)
                case .experiment:
                    return collectionView.dequeueConfiguredReusableCell(using: experimentRegistration, for: indexPath, item: item)
                case .subjectID:
                    return collectionView.dequeueConfiguredReusableCell(using: subjectIDRegistration, for: indexPath, item: item)
                case .notes:
                    return collectionView.dequeueConfiguredReusableCell(using: notesRegistration, for: indexPath, item: item)
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
extension UseCaseDetailEditViewModel {
    private func createHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { (cell, indexPath, item) in
            guard let section = Section(rawValue: indexPath.section) else { return }
            var content = UIListContentConfiguration.groupedHeader()
            content.text = section.displayText
            cell.contentConfiguration = content
        }
    }
    private func createTitleCellRegistration() -> UICollectionView.CellRegistration<TextFieldCell, Item> {
        return UICollectionView.CellRegistration<TextFieldCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.useCase.title, at: indexPath, delegate: self)
            cell.textField.autocapitalizationType = .words
            cell.textField.autocorrectionType = .no
            cell.textField.clearsOnBeginEditing = self.isNew
        }
    }
    private func createSubjectIDCellRegistration() -> UICollectionView.CellRegistration<TextFieldCell, Item> {
        return UICollectionView.CellRegistration<TextFieldCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.useCase.subjectID, at: indexPath, delegate: self)
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
            cell.textField.smartDashesType = .no
            cell.textField.smartQuotesType = .no
            cell.textField.smartInsertDeleteType = .no
            cell.textField.spellCheckingType = .no
        }
    }
    private func createExperimentCellRegistration() -> UICollectionView.CellRegistration<PickerViewCell, Item> {
        return UICollectionView.CellRegistration<PickerViewCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(dataSource: self, delegate: self)
        }
    }
    private func createNotesCellRegistration() -> UICollectionView.CellRegistration<TextViewCell, Item> {
        return UICollectionView.CellRegistration<TextViewCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            cell.configure(with: self.useCase.notes, at: indexPath, delegate: self)
        }
    }
}

// MARK: TextInputCellDelegate
extension UseCaseDetailEditViewModel: TextInputCellDelegate {
    func textChangedAt(indexPath: IndexPath, replacementString string: String) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .title:
            useCase.title = string
        case .subjectID:
            useCase.subjectID = string
        case .notes:
            useCase.notes = string
        default:
            return
        }
    }
}

// MARK: UIPickerViewDataSource
extension UseCaseDetailEditViewModel: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return experiments?.count ?? 0
    }
}

// MARK: UIPickerViewDelegate
extension UseCaseDetailEditViewModel: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return experiments?[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        useCase.experiment = experiments?[row]
    }
}

