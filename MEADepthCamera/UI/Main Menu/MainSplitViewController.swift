//
//  MainSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 10/29/21.
//

import UIKit

/// A UISplitViewController subclass that displays a three-column split view and passes data between the list and detail view controllers.
class MainSplitViewController: UISplitViewController {
    
    /// The currently selected item in the list column. The list view controller uses this so it can re-select the same row every time it reloads its data.
    var selectedItemID: ListItem.ID?
    
    // Convenience getters for each column's navigation controller.
    private var primaryNavigationController: UINavigationController? {
        viewController(for: .primary) as? UINavigationController
    }
    private var supplementaryNavigationController: UINavigationController? {
        viewController(for: .supplementary) as? UINavigationController
    }
    private var secondaryNavigationController: UINavigationController? {
        viewController(for: .secondary) as? UINavigationController
    }
    
//    private var isInitialLaunch: Bool = true
    
    deinit {
        print("MainSplitViewController deinitialized.")
    }
    
    // MARK: VC Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayModeButtonVisibility = .always
        delegate = self
        primaryNavigationController?.delegate = self
        supplementaryNavigationController?.delegate = self
        secondaryNavigationController?.delegate = self
    }
    
    // MARK: Transition to Use Case List
    /// Shows the UseCaseListViewController when the user taps the "Use Cases" button in the main menu.
    func transitionToUseCaseList() {
        if isCollapsed {
            show(.supplementary)
        } else {
            supplementaryNavigationController?.popToRootViewController(animated: true)
            show(.secondary)
        }
    }
    
    // MARK: Transition to Task List
    /// Shows the TaskListViewController when the user selects a Use Case to start recording for.
    func transitionToTaskList(with useCase: UseCase) {
        let storyboard = UIStoryboard(name: StoryboardName.taskList, bundle: nil)
        guard let taskListVC = storyboard.instantiateViewController(withIdentifier: StoryboardID.taskListVC) as? TaskListViewController
        else { return }
        taskListVC.configure(with: useCase)
        if isCollapsed {
            primaryNavigationController?.pushViewController(taskListVC, animated: true)
        } else {
            supplementaryNavigationController?.pushViewController(taskListVC, animated: true)
        }
    }
    
    // MARK: Show Use Case Detail
    /// Shows the UseCaseDetailViewController for the Use Case that's selected in the list.
    func showUseCaseDetail(_ useCase: UseCase, isNew: Bool = false) {
        guard let id = useCase.id, id != selectedItemID else { return }
        selectedItemID = id
        if let useCaseDetailVC = secondaryNavigationController?.topViewController as? UseCaseDetailViewController {
            useCaseDetailVC.configure(with: useCase, isNew: isNew)
            show(.secondary)
        } else if let useCaseDetailVC = secondaryNavigationController?.viewControllers.first as? UseCaseDetailViewController {
            useCaseDetailVC.configure(with: useCase, isNew: isNew)
            secondaryNavigationController?.popToRootViewController(animated: true)
        }
    }
    
    // MARK: Show Task Detail
    /// Shows the TaskDetailViewController for the Task that's selected in the list.
    func showTaskDetail(_ task: Task, useCase: UseCase) {
        guard let id = task.id, id != selectedItemID else { return }
        selectedItemID = id
        
        if let taskDetailVC = secondaryNavigationController?.topViewController as? TaskDetailViewController {
            taskDetailVC.configure(with: task, useCase: useCase)
        } else {
            let storyboard = UIStoryboard(name: StoryboardName.taskList, bundle: nil)
            guard let taskDetailVC = storyboard.instantiateViewController(
                withIdentifier: StoryboardID.taskDetailVC) as? TaskDetailViewController
            else { fatalError() }
            taskDetailVC.configure(with: task, useCase: useCase)
            
            if isCollapsed {
                primaryNavigationController?.pushViewController(taskDetailVC, animated: true)
            } else {
//                showDetailViewController(taskDetailVC, sender: nil)
                secondaryNavigationController?.pushViewController(taskDetailVC, animated: true)
            }
        }
    }
    
    // MARK: Show Camera
    /// Presents the CameraViewController in full screen when the user chooses to start recording a Task.
    func showCamera(task: Task, useCase: UseCase) {
        let storyboard = UIStoryboard(name: StoryboardName.camera, bundle: nil)
        guard let cameraNavController = storyboard.instantiateViewController(withIdentifier: StoryboardID.cameraNavController) as? UINavigationController,
              let cameraViewController = cameraNavController.topViewController as? CameraViewController
        else { return }
        cameraViewController.configure(useCase: useCase, task: task)
        show(cameraNavController, sender: nil)
    }
}

// MARK: UINavigationControllerDelegate
extension MainSplitViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is UseCaseListViewController, isCollapsed {
//            debugPrint(navigationController)
            selectedItemID = nil
        }
    }
}

// MARK: UISplitViewControllerDelegate
extension MainSplitViewController: UISplitViewControllerDelegate {
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .primary
    }
    
//    func splitViewController(_ svc: UISplitViewController, willShow column: UISplitViewController.Column) {
//        debugPrint(column.rawValue)
//    }
//
//    func splitViewController(_ svc: UISplitViewController, willHide column: UISplitViewController.Column) {
//        debugPrint(column.rawValue)
//    }
}
