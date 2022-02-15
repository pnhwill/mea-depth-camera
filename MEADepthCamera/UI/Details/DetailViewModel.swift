//
//  DetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/25/21.
//

import UIKit

protocol DetailViewModel: NavigationTitleProviding {
    
    func createLayout() -> UICollectionViewLayout
    func configureDataSource(for collectionView: UICollectionView)
    func applyInitialSnapshots()
    
}

