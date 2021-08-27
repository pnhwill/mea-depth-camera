//
//  UseCaseListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import CoreData

class UseCaseListViewController: UITableViewController {
    
    @IBOutlet var filterSegmentedControl: UISegmentedControl!
    
    static let unwindFromListSegueIdentifier = "UnwindFromUseCaseListSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var useCaseListDataSource: UseCaseListDataSource?
    private var filter: UseCaseListDataSource.Filter {
        return UseCaseListDataSource.Filter(rawValue: filterSegmentedControl.selectedSegmentIndex) ?? .today
    }
    
    // MARK: Navigation
    func configure(with currentUseCase: UseCase?) {
        if useCaseListDataSource == nil {
            useCaseListDataSource = UseCaseListDataSource(useCaseDeletedAction: { deletedUseCaseID in
                // handle use case deleted
                if deletedUseCaseID == self.useCaseListDataSource?.currentUseCaseID {
                    self.useCaseListDataSource?.currentUseCaseID = nil
                }
            }, useCaseChangedAction: {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
        }
        useCaseListDataSource?.currentUseCaseID = currentUseCase?.id
        tableView.dataSource = useCaseListDataSource
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.unwindFromListSegueIdentifier,
           //let destination = segue.destination as? MainMenuViewController,
           let cell = sender as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            // Return to main menu with selected use case as current use case
            let rowIndex = indexPath.row
            guard let useCase = useCaseListDataSource?.useCase(at: rowIndex) else {
                fatalError("Couldn't find data source for use case list.")
            }
            useCaseListDataSource?.currentUseCaseID = useCase.id
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Search bar controller
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = useCaseListDataSource
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
        }
    }
    
    // MARK: Actions
    
    @IBAction func addButtonTriggered(_ sender: UIBarButtonItem) {
        addUseCase()
    }
    
    @IBAction func segmentControlChanged(_ sender: UISegmentedControl) {
        useCaseListDataSource?.filter = filter
        tableView.reloadData()
    }
    
    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        guard let context = useCaseListDataSource?.persistentContainer.viewContext else { return }
        let useCase = UseCase(context: context)
        useCase.date = Date()
        useCase.id = UUID()
        detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
            self.useCaseListDataSource?.add(useCase, completion: { (index) in
                DispatchQueue.main.async {
                    if let index = index {
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            })
        })
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Push the detail view when the info button is pressed.
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        
        
        let rowIndex = indexPath.row
        guard let useCase = useCaseListDataSource?.useCase(at: rowIndex) else {
            fatalError("Couldn't find data source for use case list.")
        }
        
        detailViewController.configure(with: useCase, editAction: { useCase in
            self.useCaseListDataSource?.update(useCase, at: rowIndex) { success in
                if success {
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                } else {
                    DispatchQueue.main.async {
                        let alertTitle = NSLocalizedString("Can't Update Use Case", comment: "error updating use case title")
                        let alertMessage = NSLocalizedString("An error occured while attempting to update the use case.", comment: "error updating use case message")
                        let actionTitle = NSLocalizedString("OK", comment: "ok action title")
                        let actions = [UIAlertAction(title: actionTitle, style: .default, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        })]
                        self.alert(title: alertTitle, message: alertMessage, actions: actions)
                    }
                }
            }
        })
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

// MARK: UINavigationControllerDelegate

extension UseCaseListViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if let mainMenuViewController = viewController as? MainMenuViewController {
            mainMenuViewController.configure(with: useCaseListDataSource?.useCase(with: useCaseListDataSource?.currentUseCaseID))
        }
    }
}
