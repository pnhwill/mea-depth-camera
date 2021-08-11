//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class UseCaseDetailViewController: UITableViewController {
    typealias UseCaseChangeAction = (SavedUseCase) -> Void
    
    private var useCase: SavedUseCase?
    private var tempUseCase: SavedUseCase?
    private var dataSource: UITableViewDataSource?
    private var useCaseEditAction: UseCaseChangeAction?
    private var useCaseAddAction: UseCaseChangeAction?
    private var isNew = false
    
    func configure(with useCase: SavedUseCase, isNew: Bool = false, addAction: UseCaseChangeAction? = nil, editAction: UseCaseChangeAction? = nil) {
        self.useCase = useCase
        self.isNew = isNew
        self.useCaseAddAction = addAction
        self.useCaseEditAction = editAction
        if isViewLoaded {
            setEditing(isNew, animated: false)
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
    }
    
    // MARK: Mode Transitions
    
    fileprivate func transitionToViewMode(_ useCase: SavedUseCase) {
        if isNew {
            let addUseCase = tempUseCase ?? useCase
            dismiss(animated: true) {
                self.useCaseAddAction?(addUseCase)
            }
            return
        }
        if let tempUseCase = tempUseCase {
            self.useCase = tempUseCase
            self.tempUseCase = nil
            useCaseEditAction?(tempUseCase)
            dataSource = UseCaseDetailViewDataSource(useCase: tempUseCase)
        } else {
            dataSource = UseCaseDetailViewDataSource(useCase: useCase)
        }
        navigationItem.title = NSLocalizedString("View Use Case", comment: "view use case nav title")
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
    }
    
    fileprivate func transitionToEditMode(_ useCase: SavedUseCase) {
        dataSource = UseCaseDetailEditDataSource(useCase: useCase) { useCase in
            self.tempUseCase = useCase
            self.editButtonItem.isEnabled = true
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
            tableView.backgroundColor = .secondarySystemBackground
        } else {
            transitionToViewMode(useCase)
            tableView.backgroundColor = .systemBackground
        }
        tableView.dataSource = dataSource
        tableView.reloadData()
    }
    
    @objc
    func cancelButtonTrigger() {
        if isNew {
            dismiss(animated: true, completion: nil)
        } else {
            tempUseCase = nil
            setEditing(false, animated: true)
        }
        
    }
}

extension UseCaseDetailViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if isEditing {
            cell.backgroundColor = .secondarySystemBackground
//            guard let editRow = UseCaseDetailEditDataSource.UseCaseRow(rawValue: indexPath.row) else {
//                return
//            }
        } else {
            cell.backgroundColor = .systemBackground
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
