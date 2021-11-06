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
