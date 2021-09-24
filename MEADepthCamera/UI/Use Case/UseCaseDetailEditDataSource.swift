//
//  UseCaseDetailEditDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

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