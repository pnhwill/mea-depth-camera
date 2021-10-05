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
    
    private var task: Task?
    //private var dataSource: TaskInstructionsDataSource?
    
    func configure(with task: Task) {
        self.task = task
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let _ = task else {
            fatalError("No task found for instructions view")
        }
        //dataSource = TaskInstructionsDataSource(task: task)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUI()
    }
    
    private func refreshUI() {
        nameLabel.text = task?.name
        instructionsLabel.text = task?.instructions
    }
    
}
