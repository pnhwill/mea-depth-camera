//
//  DetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/31/22.
//

import UIKit

protocol DetailViewController where Self: UIViewController {
    func configure(with: UUID, isNew: Bool)
    func hide()
}
