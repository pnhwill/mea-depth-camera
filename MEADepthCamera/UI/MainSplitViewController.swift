//
//  MainSplitViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import UIKit

final class MainSplitViewController: UISplitViewController {
    
    var selectedList: SidebarItem? {
        didSet {
            guard let selectedList = selectedList,
                  selectedList != oldValue,
                  let navController = viewController(for: .supplementary) as? UINavigationController,
                  let listViewController = navController.topViewController as? ListViewController
            else { return }
            let listViewModel: ListViewModel
            switch selectedList {
            case .useCases:
                listViewModel = UseCaseListViewModel()
            case .tasks:
                listViewModel = TaskListViewModel()
            }
            listViewController.configure(viewModel: listViewModel)
            show(.supplementary)
        }
    }
    
    private(set) var selectedItemID: ListItem.ID?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    func showDetail(itemID: ListItem.ID, isNew: Bool = false) {
        print(#function)
//        guard let selectedList = selectedList,
//              let navController = viewController(for: .secondary) as? UINavigationController
//        else { return }
//        if let selectedItemID = selectedItemID, itemID == selectedItemID {
//            return
//        }
//        selectedItemID = itemID
//        let detailViewController: DetailViewController
//        switch selectedList {
//        case .entities:
//            detailViewController = navController.topViewController as? EntityDetailViewController ?? UIStoryboard(storyboard: .main).instantiateViewController()
//        case .things:
//            detailViewController =  navController.topViewController as? ThingDetailViewController ?? UIStoryboard(storyboard: .main).instantiateViewController()
//        }
//        detailViewController.configure(with: itemID, isNew: isNew)
//        navController.setViewControllers([detailViewController], animated: true)
//        show(.secondary)
    }
    
    func hideDetail() {
        print(#function)
//        selectedItemID = nil
//        guard let navController = viewController(for: .secondary) as? UINavigationController,
//              let detailViewController = navController.topViewController as? DetailViewController
//        else { return }
//        detailViewController.hide()
    }

}

