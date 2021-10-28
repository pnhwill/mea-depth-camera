//
//  UseCaseDetailEditDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class UseCaseDetailEditModel: NSObject, DetailViewModel {
    
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
    
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    private lazy var experimentProvider: ExperimentProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = ExperimentProvider(with: container, fetchedResultsControllerDelegate: nil)
        return provider
    }()
    
    private var useCase: UseCase
    
    private var experiments: [Experiment]? {
        return experimentProvider.fetchedResultsController.fetchedObjects
    }
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
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

extension UseCaseDetailEditModel {
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
extension UseCaseDetailEditModel: TextInputCellDelegate {
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
extension UseCaseDetailEditModel: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return experiments?.count ?? 0
    }
}

// MARK: UIPickerViewDelegate
extension UseCaseDetailEditModel: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return experiments?[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        useCase.experiment = experiments?[row]
    }
}

// MARK: NSFetchedResultsControllerDelegate
//extension UseCaseDetailEditModel: NSFetchedResultsControllerDelegate {
//    
//}











class UseCaseDetailEditDataSource: NSObject {
    typealias UseCaseChangeAction = (UseCaseChanges) -> Void
    
    enum UseCaseSection: Int, CaseIterable {
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
        
        var numRows: Int {
            switch self {
            default:
                return 1
            }
        }
        
        func cellIdentifier() -> String {
            switch self {
            case .title:
                return "EditTitleCell"
            case .experiment:
                return "EditExperimentCell"
            case .subjectID:
                return "EditSubjectIDCell"
            case .notes:
                return "EditNotesCell"
            }
        }
    }
    
    struct UseCaseChanges {
        var title: String?
        var experiment: Experiment?
        var subjectID: String?
        var notes: String?
    }
    
    private var useCase: UseCase
    private var useCaseChanges: UseCaseChanges
    private var useCaseChangeAction: UseCaseChangeAction?
    
    // Core Data provider for experiment selection
    lazy var experimentProvider: ExperimentProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = ExperimentProvider(with: container, fetchedResultsControllerDelegate: self)
        return provider
    }()
    
    var experiments: [Experiment]? {
        return experimentProvider.fetchedResultsController.fetchedObjects
    }
    
    init(useCase: UseCase, changeAction: @escaping UseCaseChangeAction) {
        self.useCase = useCase
        self.useCaseChanges = UseCaseChanges(title: useCase.title, subjectID: useCase.subjectID, notes: useCase.notes)
        self.useCaseChangeAction = changeAction
        super.init()
    }
    
    private func dequeueAndConfigureCell(for indexPath: IndexPath, from tableView: UITableView) -> UITableViewCell {
        guard let section = UseCaseSection(rawValue: indexPath.section) else {
            fatalError("Section index out of range")
        }
        let identifier = section.cellIdentifier()
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        
        switch section {
        case .title:
            if let titleCell = cell as? EditTitleCell {
                titleCell.configure(title: useCaseChanges.title) { title in
                    self.useCaseChanges.title = title
                    self.useCaseChangeAction?(self.useCaseChanges)
                }
            }
        case .experiment:
            if let experimentCell = cell as? EditExperimentCell {
                experimentCell.configure(dataSource: self, delegate: self)
                let selectedRow = experimentCell.pickerView.selectedRow(inComponent: 0)
                useCaseChanges.experiment = experiments?[selectedRow]
                useCaseChangeAction?(useCaseChanges)
            }
        case .subjectID:
            if let subjectIDCell = cell as? EditSubjectIDCell {
                subjectIDCell.configure(subjectID: useCaseChanges.subjectID) { subjectID in
                    self.useCaseChanges.subjectID = subjectID
                    self.useCaseChangeAction?(self.useCaseChanges)
                }
            }
        case .notes:
            if let notesCell = cell as? EditNotesCell {
                notesCell.configure(notes: useCaseChanges.notes) { notes in
                    self.useCaseChanges.notes = notes
                    self.useCaseChangeAction?(self.useCaseChanges)
                }
            }
        }
        return cell
    }
    
}

// MARK: UITableViewDataSource

extension UseCaseDetailEditDataSource: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return UseCaseSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UseCaseSection(rawValue: section)?.numRows ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dequeueAndConfigureCell(for: indexPath, from: tableView)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = UseCaseSection(rawValue: section) else {
            fatalError("Section index out of range")
        }
        return section.displayText
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: UIPickerViewDataSource
extension UseCaseDetailEditDataSource: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return experiments?.count ?? 0
    }
}

// MARK: UIPickerViewDelegate
extension UseCaseDetailEditDataSource: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return experiments?[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        useCaseChanges.experiment = experiments?[row]
        useCaseChangeAction?(useCaseChanges)
    }
}

// MARK: NSFetchedResultsControllerDelegate
extension UseCaseDetailEditDataSource: NSFetchedResultsControllerDelegate {
    
}
