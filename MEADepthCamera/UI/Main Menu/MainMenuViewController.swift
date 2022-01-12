//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

/// A view controller for the app's top-level menu, providing a starting point to reach every part of the app.
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
