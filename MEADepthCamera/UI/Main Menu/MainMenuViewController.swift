//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class MainMenuViewController: UIViewController {
    
    @IBOutlet private weak var useCaseListButton: UIButton!
    
    static let showTaskListSegueIdentifier = "ShowTaskListSegue"
    static let showUseCaseListSegueIdentifier = "ShowUseCaseListSegue"
    static let unwindFromListSegueIdentifier = "UnwindFromUseCaseListSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var dataSource: MainMenuDataSource?
    
    // MARK: - Navigation
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == Self.showTaskListSegueIdentifier, let destination = segue.destination as? TaskListViewController {
//            guard let useCase = dataSource?.useCase else {
//                fatalError("Couldn't find data source for use case.")
//            }
//            destination.configure(with: useCase)
//        }
//    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
    
    // MARK: - Actions
    
    @IBAction func showList(_ sender: UIButton) {
        let useCaseListVC = UseCaseListViewController()
        show(useCaseListVC, sender: self)
    }
    
}
