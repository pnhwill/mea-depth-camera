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
    
    static let showDetailSegueIdentifier = "ShowUseCaseDetailSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var useCaseListDataSource: UseCaseListDataSource?
    private var filter: UseCaseListDataSource.Filter {
        return UseCaseListDataSource.Filter(rawValue: filterSegmentedControl.selectedSegmentIndex) ?? .today
    }
    
    // Core Data and search
    //var persistentContainer: PersistentContainer?
    
    // MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showDetailSegueIdentifier,
            let destination = segue.destination as? UseCaseDetailViewController,
            let cell = sender as? UITableViewCell,
            let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let useCase = useCaseListDataSource?.useCase(at: rowIndex) else {
                fatalError("Couldn't find data source for use case list.")
            }
            destination.configure(with: useCase, editAction: { useCase in
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
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        useCaseListDataSource = UseCaseListDataSource(useCaseDeletedAction: {
            // handle use case deleted
        }, useCaseChangedAction: {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        })
        tableView.dataSource = useCaseListDataSource
        // Search bar controller
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = useCaseListDataSource
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshBackground()
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
        refreshBackground()
    }
    
    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        guard let context = useCaseListDataSource?.persistentContainer.viewContext else { return }
        let useCase = UseCase(context: context)
        useCase.date = Date()
        useCase.id = UUID()
        detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
            self.useCaseListDataSource?.add(useCase, completion: { (success) in
                DispatchQueue.main.async {
                    if success {
                        self.tableView.reloadData()
                    }
                }
            })
        })
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }

    
    private func refreshBackground() {
        tableView.backgroundView = nil
        let backgroundView = UIView()
        // update background colors
//        if let backgroundColors = filter.backgroundColors {
//            let gradientBackgroundLayer = CAGradientLayer()
//            gradientBackgroundLayer.colors = backgroundColors
//            gradientBackgroundLayer.frame = tableView.frame
//            backgroundView.layer.addSublayer(gradientBackgroundLayer)
//        } else {
//            backgroundView.backgroundColor = filter.substituteBackgroundColor
//        }
        tableView.backgroundView = backgroundView
    }
    
}



