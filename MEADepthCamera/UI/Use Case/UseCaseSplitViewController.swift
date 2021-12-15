//
//  UseCaseSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 10/29/21.
//

import UIKit

/// A view controller that displays a two-column split view and passes data between the list and detail view controllers.
class UseCaseSplitViewController: UISplitViewController {
    
    var selectedItemID: ListItem.ID?
    
    deinit {
        print("UseCaseSplitViewController deinitialized.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayModeButtonVisibility = .never
    }
    
    @IBAction func unwindFromTasks(unwindSegue: UIStoryboardSegue) {
    }
    
    func showDetail(with useCase: UseCase, isNew: Bool = false) {
        guard let detailViewController = self.viewController(for: .secondary) as? UseCaseDetailViewController,
              let id = useCase.id,
              id != selectedItemID
        else { return }
        detailViewController.configure(with: useCase, isNew: isNew)
        selectedItemID = id
        if isCollapsed {
            showDetailViewController(detailViewController, sender: self)
        }
    }
    
    func showTaskList(with useCase: UseCase) {
        let storyboard = UIStoryboard(name: StoryboardName.taskList, bundle: nil)
        guard let taskSplitVC = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.taskSplitVC) as? TaskSplitViewController
        else {
            assertionFailure("failed to instantiate UseCaseSplitVC.")
            return
        }
        taskSplitVC.configure(with: useCase)
        setRootViewController(taskSplitVC, animated: true)
    }
}

