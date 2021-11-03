//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import Combine

class UseCaseDetailViewController: DetailViewController {
    
    private var useCase: UseCase?
    private var isNew = false
    private var useCaseDidChangeSubscriber: Cancellable?
    
    func configure(with useCase: UseCase, isNew: Bool = false) {
        self.useCase = useCase
        self.isNew = isNew
        setEditing(isNew, animated: false)
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        
        useCaseDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .useCaseDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.useCaseId] }
            .sink { [weak self] id in
                guard let useCaseId = self?.useCase?.id,
                      useCaseId == id as? UUID
                else { return }
                self?.checkValidUseCase()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let navigationController = navigationController,
           !navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(true, animated: animated)
        }
    }
}

// MARK: Editing Mode Transitions
extension UseCaseDetailViewController {
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let useCase = useCase else { fatalError() }
        if editing {
            transitionToEditMode(useCase)
        } else {
            transitionToViewMode(useCase)
        }
        configureCollectionView()
    }
    
    func transitionToViewMode(_ useCase: UseCase) {
        // Resign the first responder
        view.endEditing(true)
        // Save the use case to persistent storage if needed
        if useCase.hasChanges {
            let container = AppDelegate.shared.coreDataStack.persistentContainer
            let context = useCase.managedObjectContext
            let contextSaveInfo: ContextSaveContextualInfo = isNew ? .addUseCase : .updateUseCase
            container.saveContext(backgroundContext: context, with: contextSaveInfo)
        }
        isNew = false
        viewModel = UseCaseDetailViewModel(useCase: useCase)
        navigationItem.title = NSLocalizedString("View Use Case", comment: "view use case nav title")
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
    }
    
    func transitionToEditMode(_ useCase: UseCase) {
        editButtonItem.isEnabled = false
        viewModel = UseCaseDetailEditModel(useCase: useCase, isNew: isNew)
        navigationItem.title = isNew ? NSLocalizedString("Add Use Case", comment: "add use case nav title") : NSLocalizedString("Edit Use Case", comment: "edit use case nav title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTrigger))
    }
    
    @objc
    func cancelButtonTrigger() {
        useCase?.managedObjectContext?.rollback()
        if isNew {
            navigationController?.popToRootViewController(animated: true)
        } else {
            setEditing(false, animated: true)
        }
    }
    
    private func checkValidUseCase() {
        if let title = useCase?.title, let subjectID = useCase?.subjectID {
            let isValid = !title.isEmpty && !subjectID.isEmpty
            self.editButtonItem.isEnabled = isValid
        }
    }
}

















// MARK: OLD
class OldUseCaseDetailViewController: UITableViewController {
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
        if isViewLoaded {
            setEditing(isNew, animated: false)
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if useCase != nil {
            setEditing(isNew, animated: false)
        }
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
//            dataSource = UseCaseDetailViewDataSource(useCase: useCase)
        } else {
//            dataSource = UseCaseDetailViewDataSource(useCase: useCase)
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
        useCase?.experiment = useCaseChanges.experiment
        useCase?.subjectID = useCaseChanges.subjectID
        useCase?.notes = useCaseChanges.notes
    }
    
}

// MARK: UITableViewController

extension OldUseCaseDetailViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if isEditing {
            cell.backgroundColor = .tertiarySystemGroupedBackground
//            guard let editRow = UseCaseDetailEditDataSource.UseCaseRow(rawValue: indexPath.row) else {
//                return
//            }
        } else {
            cell.backgroundColor = .systemGroupedBackground
//            guard let viewRow = UseCaseDetailViewDataSource.UseCaseRow(rawValue: indexPath.row) else {
//                return
//            }
//            if viewRow == .title {
//                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
//            } else {
//                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
//            }
        }
    }
}
