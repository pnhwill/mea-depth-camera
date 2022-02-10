//
//  TaskSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import UIKit

class TaskSplitViewController: UISplitViewController {
    
    var selectedItemID: OldListItem.ID?
    
    private var useCase: UseCase? {
        didSet {
            guard let useCase = useCase,
                  let taskListNavController = viewController(for: columnForTaskList) as? UINavigationController,
                  let taskListVC = taskListNavController.topViewController as? TaskListViewController
            else { return }
//            taskListVC.configure(with: useCase)
        }
    }
    
    deinit {
        print("TaskSplitViewController deinitialized.")
    }
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayModeButtonVisibility = .never
    }
    
    func showDetail(with task: Task) {
        guard let detailViewController = self.viewController(for: .secondary) as? TaskDetailViewController,
              let useCase = useCase,
              let id = task.id,
              id != selectedItemID
        else { return }
        detailViewController.configure(with: task, useCase: useCase)
        selectedItemID = id
        if isCollapsed {
            showDetailViewController(detailViewController, sender: self)
        }
    }
    
    func showCamera(with useCase: UseCase, task: Task) {
        let storyboard = UIStoryboard(name: StoryboardName.camera, bundle: nil)
        guard let cameraNavController = storyboard.instantiateViewController(withIdentifier: StoryboardID.cameraNavController) as? UINavigationController,
              let cameraViewController = cameraNavController.topViewController as? CameraViewController
        else { return }
        cameraViewController.configure(useCase: useCase, task: task)
        show(cameraNavController, sender: nil)
    }
}

extension TaskSplitViewController {
    
    private var columnForTaskList: UISplitViewController.Column {
        switch traitCollection.horizontalSizeClass {
        case .compact:
            return .compact
        default:
            return .primary
        }
    }
}
