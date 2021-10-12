//
//  TaskInstructionsViewController.swift
//  MEADepthCamera
//
//  Created by Will on 10/5/21.
//

import UIKit

class TaskInstructionsViewController: UIViewController {
    
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var instructionsLabel: UILabel!
    
    private var dataSource: TaskInstructionsDataSource?
    
    func configure(with task: Task) {
        dataSource = TaskInstructionsDataSource(task: task)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard dataSource != nil else {
            fatalError("No data source found for task instructions view")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUI()
    }
    
    private func refreshUI() {
        nameLabel.text = dataSource?.task.name
        instructionsLabel.text = dataSource?.task.instructions
    }
    
}
