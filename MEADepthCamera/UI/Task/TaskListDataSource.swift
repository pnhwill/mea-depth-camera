//
//  TaskListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit
import CoreData

class TaskListDataSource: NSObject, ListDataSource {
    
    // MARK: Properties
    var navigationTitle: String = "Choose Task to Record"
    
    private var useCase: UseCase
    private lazy var tasks: [Task]? = {
        return useCase.experiment?.tasks?.allObjects as? [Task]
    }()
    
    init(useCase: UseCase) {
        self.useCase = useCase
        super.init()
        sortTasks()
    }
    
    func task(at row: Int) -> Task? {
        return tasks?[row]
    }
    
    func sortTasks() {
        guard let p = tasks?.partition(by: { useCase.recordingsCount(for: $0) > 0 }) else { return }
        tasks?[..<p].sort { $0.name! < $1.name! }
        tasks?[p...].sort { $0.name! < $1.name! }
    }
    
}

// MARK: UITableViewDataSource
extension TaskListDataSource: UITableViewDataSource {
    static let taskListCellIdentifier = "TaskListCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.taskListCellIdentifier, for: indexPath) as? TaskListCell else {
            fatalError("###\(#function): Failed to dequeue a TaskListCell. Check the cell reusable identifier in Main.storyboard.")
        }
        if let currentTask = task(at: indexPath.row), let taskName = currentTask.name {
            let recordingsCountText = currentTask.recordingsCountText(for: useCase)
            cell.configure(name: taskName, recordingsCountText: recordingsCountText)
        }
        return cell
    }
}
