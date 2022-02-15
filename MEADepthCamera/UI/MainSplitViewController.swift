//
//  MainSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import UIKit

/// A `UISplitViewController` subclass that displays a three-column split view and passes data between the list and detail view controllers.
final class MainSplitViewController: UISplitViewController {
    
    // MARK: Selections
    
    /// The currently selected item in the sidebar column, i.e. the view model being shown in the list column.
    var selectedList: SidebarItem? {
        didSet {
            guard let selectedList = selectedList, selectedList != oldValue else { return }
            showList(selectedList)
        }
    }
    
    /// The currently selected item in the list column.
    ///
    /// The list view controller uses this so it can re-select the same row every time it reloads its data.
    private(set) var selectedItemID: ListItem.ID?
    
    // MARK: Columns
    
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

    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    // MARK: Detail
    
    /// Shows the DetailViewController for the item that's selected in the list.
    func showDetail(itemID: ListItem.ID, isNew: Bool = false) {
        guard let selectedList = selectedList,
              let navController = secondaryNavigationController
        else { return }
        if let selectedItemID = selectedItemID, itemID == selectedItemID {
            return
        }
        selectedItemID = itemID
        let detailViewController: DetailViewController
        switch selectedList {
        case .useCases:
            detailViewController = navController.topViewController as? UseCaseDetailViewController ?? UIStoryboard(storyboard: .detail).instantiateViewController()
        case .tasks:
            detailViewController =  navController.topViewController as? TaskDetailViewController ?? UIStoryboard(storyboard: .detail).instantiateViewController()
        default:
            return
        }
        detailViewController.configure(with: itemID, isNew: isNew)
        navController.setViewControllers([detailViewController], animated: true)
        show(.secondary)
    }
    
    /// Clears the currently selected item and tells the detail VC to hide its content.
    func hideDetail() {
        selectedItemID = nil
        guard let detailViewController = secondaryNavigationController?.topViewController as? DetailViewController
        else { return }
        detailViewController.hide()
    }
    
    // MARK: Camera
    
    /// Presents the `CameraViewController` in full screen when the user chooses to start recording a Task.
    func showCamera(task: Task, useCase: UseCase) {
        let storyboard = UIStoryboard(storyboard: .camera)
        guard let cameraNavController = storyboard.instantiateViewController(withIdentifier: StoryboardID.cameraNavController) as? UINavigationController,
              let taskStartVC = cameraNavController.topViewController as? TaskStartViewController
        else { return }
        taskStartVC.configure(with: task, useCase: useCase)
        present(cameraNavController, animated: true, completion: nil)
    }

}

// MARK: List
extension MainSplitViewController {
    
    /// Reconfigures the ListViewController when the user taps a cell in the sidebar main menu.
    private func showList(_ selectedList: SidebarItem) {
        guard let listViewController = supplementaryNavigationController?.topViewController as? ListViewController
        else { return }
        let listViewModel: ListViewModel
        switch selectedList {
        case .useCases:
            listViewModel = UseCaseListViewModel()
        case .tasks:
            listViewModel = TaskListViewModel()
        default:
            return
        }
        listViewController.configure(viewModel: listViewModel)
        show(.supplementary)
    }
}
