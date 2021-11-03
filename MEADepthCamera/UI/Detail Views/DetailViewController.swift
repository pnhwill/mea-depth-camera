//
//  DetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 10/25/21.
//

import UIKit

/// Base class for detail UIViewControllers that list editable information from a Core Data model object.
class DetailViewController: UIViewController, UICollectionViewDelegate {
    
    var viewModel: DetailViewModel?
    var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
    }
    
    func configureCollectionView() {
        configureHierarchy()
        viewModel?.configureDataSource(for: collectionView)
        viewModel?.applyInitialSnapshots()
    }
}

extension DetailViewController {
    private func configureHierarchy() {
        guard let viewModel = viewModel else { return }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: viewModel.createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }
}
