//
//  RecordingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListViewController: UITableViewController {
    
    @IBOutlet private weak var useCaseView: UseCaseSummaryView!
    
    private var dataSource: RecordingListDataSource?
    
    func configure(useCase: UseCase, task: Task) {
        dataSource = RecordingListDataSource(useCase: useCase, task: task)
    }
    
    
    
    
}

// MARK: UITableViewDelegate
extension RecordingListViewController {
    static let processingHeaderNibName = "ProcessingView"
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let isProcessed = dataSource?.isRecordingProcessed(at: section), isProcessed else { return nil }
        
        guard let views = Bundle.main.loadNibNamed(Self.processingHeaderNibName, owner: self, options: nil),
              let processingHeaderView = views[0] as? ProcessingView else { return nil }
        
        processingHeaderView.section = section
        let displayText = "Tap to Start Processing"
        processingHeaderView.configure(isProcessing: false, frameCounterText: displayText, progress: nil, startStopAction: {_ in })
        return processingHeaderView
    }
}
