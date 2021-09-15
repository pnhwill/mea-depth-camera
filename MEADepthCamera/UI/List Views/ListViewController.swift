//
//  ListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit
import CoreData

protocol ListViewControllerProtocol {
    
    associatedtype Object: NSManagedObject
    
    func configure(with object: Object)
    
}

/// Base class for UITableViewControllers that list object data from the Core Data model and present a detail view for selected cells.
class ListViewController: UITableViewController {
    
    static let mainStoryboardName = "Main"
    
    private var dataSource: ListDataSource?
    
}
