//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class MainMenuViewController: UIViewController {
    
    private var mainSplitViewController: MainSplitViewController? {
        self.splitViewController as? MainSplitViewController
    }
    
    deinit {
        print("MainMenuViewController deinitialized.")
    }
    
    @IBAction func useCaseListButtonTapped(_ sender: UIButton) {
        mainSplitViewController?.transitionToUseCaseList()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
}
