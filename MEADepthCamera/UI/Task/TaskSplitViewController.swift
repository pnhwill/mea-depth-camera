//
//  TaskSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import UIKit

class TaskSplitViewController: UISplitViewController {
    
    var selectedItemID: ListItem.ID?
    
    private var useCase: UseCase? {
        didSet {
            guard let useCase = useCase,
                  let taskListNavController = viewController(for: columnForTaskList()) as? UINavigationController,
                  let taskListVC = taskListNavController.topViewController as? TaskListViewController
            else { return }
            taskListVC.configure(with: useCase)
        }
    }
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayModeButtonVisibility = .never
    }
    
    @IBAction func unwindFromCamera(unwindSegue: UIStoryboardSegue) {
        
    }
    
    func showDetail(with task: Task) {
        guard let detailNavController = self.viewController(for: .secondary) as? UINavigationController,
              let detailViewController = detailNavController.topViewController as? TaskDetailViewController,
              let useCase = useCase,
              let id = task.id,
              id != selectedItemID
        else { return }
        detailViewController.configure(with: task, useCase: useCase)
        selectedItemID = id
        if isCollapsed {
            showDetailViewController(detailNavController, sender: self)
        }
    }
}

extension TaskSplitViewController {
    
    private func columnForTaskList() -> UISplitViewController.Column {
        switch traitCollection.horizontalSizeClass {
        case .compact:
            return .compact
        default:
            return .primary
        }
    }
}
