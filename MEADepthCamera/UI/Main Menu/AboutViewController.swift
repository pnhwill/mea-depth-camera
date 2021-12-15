//
//  AboutViewController.swift
//  MEADepthCamera
//
//  Created by Will on 12/13/21.
//

import UIKit

/// ListViewController subclass for the app's "About" view.
class AboutViewController: ListViewController {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewModel = AboutViewModel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.allowsSelection = false
    }
}
