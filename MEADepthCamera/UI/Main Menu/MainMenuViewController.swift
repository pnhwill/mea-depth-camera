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
    
    private var dataSource: MainMenuDataSource?
    
    // MARK: Navigation
    
    @IBAction func unwindFromList(unwindSegue: UIStoryboardSegue) {
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
    
}
