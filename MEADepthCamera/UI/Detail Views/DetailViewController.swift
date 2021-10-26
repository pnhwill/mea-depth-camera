//
//  DetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 10/25/21.
//

import UIKit

/// Base class for detail UIViewControllers that list editable information from a Core Data model object.
class DetailViewController<ViewModel: DetailViewModel>: UIViewController, UICollectionViewDelegate {
    
    typealias Section = ViewModel.Section
    typealias Item = ViewModel.Item
    typealias DetailDiffableDataSource = UICollectionViewDiffableDataSource<Section.ID, Item.ID>
    
    var viewModel: ViewModel?
    var collectionView: UICollectionView!
    var dataSource: DetailDiffableDataSource?
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
