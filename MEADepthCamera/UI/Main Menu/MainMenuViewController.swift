//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class MainMenuViewController: UIViewController {
    
    deinit {
        print("MainMenuViewController deinitialized.")
    }
    
    @IBAction func useCaseListButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: StoryboardName.useCaseList, bundle: nil)
        guard let useCaseSplitVC = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.useCaseSplitVC) as? UseCaseSplitViewController
        else {
            assertionFailure("failed to instantiate UseCaseSplitVC.")
            return
        }
        setRootViewController(useCaseSplitVC, animated: true)
    }
    
    @IBAction func unwindFromList(unwindSegue: UIStoryboardSegue) {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
}
