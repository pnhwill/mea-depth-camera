//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class UseCaseDetailViewController: UITableViewController {
    typealias UseCaseChangeAction = (UseCase) -> Void
    typealias UseCaseChanges = UseCaseDetailEditDataSource.UseCaseChanges
    
    private var useCase: UseCase?
    private var useCaseChanges: UseCaseChanges?
    private var dataSource: UITableViewDataSource?
    private var useCaseEditAction: UseCaseChangeAction?
    private var useCaseAddAction: UseCaseChangeAction?
    private var isNew = false
    
    func configure(with useCase: UseCase, isNew: Bool = false, addAction: UseCaseChangeAction? = nil, editAction: UseCaseChangeAction? = nil) {
        self.useCase = useCase
        self.isNew = isNew
        self.useCaseAddAction = addAction
        self.useCaseEditAction = editAction
        DispatchQueue.main.async {
            if self.isViewLoaded {
                self.setEditing(isNew, animated: false)
            }
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setEditing(isNew, animated: false)
        navigationItem.setRightBarButton(editButtonItem, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
           !navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(true, animated: animated)
        }
        self.isModalInPresentation = true
    }
    
    // MARK: Mode Transitions
    
    fileprivate func transitionToViewMode(_ useCase: UseCase) {
        if isNew {
            //let addUseCase = tempUseCase ?? useCase
            setUseCaseChanges()
            dismiss(animated: true) {
                self.useCaseAddAction?(useCase)
            }
            return
        }
        if useCaseChanges != nil {
            setUseCaseChanges()
            self.useCaseChanges = nil
            useCaseEditAction?(useCase)
            dataSource = UseCaseDetailViewDataSource(useCase: useCase)
        } else {
            dataSource = UseCaseDetailViewDataSource(useCase: useCase)
        }
        navigationItem.title = NSLocalizedString("View Use Case", comment: "view use case nav title")
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
    }
    
    fileprivate func transitionToEditMode(_ useCase: UseCase) {
        editButtonItem.isEnabled = false
        dataSource = UseCaseDetailEditDataSource(useCase: useCase) { useCaseChanges in
            self.useCaseChanges = useCaseChanges
            if let title = useCaseChanges.title, let subjectID = useCaseChanges.subjectID {
                let isValidChanges = !title.isEmpty && !subjectID.isEmpty
                self.editButtonItem.isEnabled = isValidChanges
            }
        }
        navigationItem.title = isNew ? NSLocalizedString("Add Use Case", comment: "add use case nav title") : NSLocalizedString("Edit Use Case", comment: "edit use case nav title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTrigger))
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let useCase = useCase else {
            fatalError("No use case found for detail view")
        }
        if editing {
            transitionToEditMode(useCase)
            //tableView.backgroundColor = .systemGroupedBackground
        } else {
            transitionToViewMode(useCase)
            //tableView.backgroundColor = .systemGroupedBackground
        }
        tableView.dataSource = dataSource
        tableView.reloadData()
    }
    
    @objc
    func cancelButtonTrigger() {
        if isNew {
            useCase?.managedObjectContext?.rollback()
            dismiss(animated: true, completion: nil)
        } else {
            useCaseChanges = nil
            setEditing(false, animated: true)
        }
        
    }
    
    private func setUseCaseChanges() {
        guard let useCaseChanges = useCaseChanges else { return }
        useCase?.title = useCaseChanges.title
        useCase?.subjectID = useCaseChanges.subjectID
        useCase?.notes = useCaseChanges.notes
    }
    
}

// MARK: UITableViewController

extension UseCaseDetailViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if isEditing {
            cell.backgroundColor = .tertiarySystemGroupedBackground
//            guard let editRow = UseCaseDetailEditDataSource.UseCaseRow(rawValue: indexPath.row) else {
//                return
//            }
        } else {
            cell.backgroundColor = .systemGroupedBackground
            guard let viewRow = UseCaseDetailViewDataSource.UseCaseRow(rawValue: indexPath.row) else {
                return
            }
            if viewRow == .title {
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
            } else {
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            }
        }
    }
}
