//
//  DetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/25/21.
//

import UIKit

protocol DetailViewModel {
//    associatedtype Section: Hashable
//    associatedtype Item: Hashable
//
//    typealias DetailDiffableDataSource = UICollectionViewDiffableDataSource<Section, Item>
//
//    var dataSource: DetailDiffableDataSource? { get set }
    
    func createLayout() -> UICollectionViewLayout
    func configureDataSource(for collectionView: UICollectionView)
    func applyInitialSnapshots()
}

