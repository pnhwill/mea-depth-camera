//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class MainMenuViewController: UIViewController {
    
    @IBOutlet private weak var useCaseView: MainMenuUseCaseView!
    @IBOutlet private weak var addUseCaseButton: UIButton!
    @IBOutlet private weak var useCaseListButton: UIButton!
    @IBOutlet private weak var startButton: UIButton!
    
    static let showRecordingListSegueIdentifier = "ShowRecordingListSegue"
    static let showUseCaseListSegueIdentifier = "ShowUseCaseListSegue"
    static let unwindFromListSegueIdentifier = "UnwindFromUseCaseListSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var mainMenuDataSource: MainMenuDataSource?
    
    // MARK: - Navigation
    
    func configure(with useCase: UseCase?) {
        // Setup main menu
        if mainMenuDataSource == nil {
            mainMenuDataSource = MainMenuDataSource(currentUseCaseChangedAction: { currentUseCase in
                DispatchQueue.main.async {
                    if let useCase = currentUseCase {
                        self.refreshUseCaseView(title: useCase.title, subjectID: useCase.subjectID)
                        self.startButton.isEnabled = true
                    } else {
                        self.refreshUseCaseView(title: "No Use Case Selected", subjectID: nil)
                        self.startButton.isEnabled = false
                    }
                }
            })
        }
        mainMenuDataSource?.updateCurrentUseCase(useCase)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showRecordingListSegueIdentifier, let destination = segue.destination as? RecordingListViewController {
//            destination.persistentContainer = mainMenuDataSource?.persistentContainer
            guard let useCase = mainMenuDataSource?.currentUseCase else {
                fatalError("Couldn't find data source for use case.")
            }
            destination.configure(with: useCase)
        }
        if segue.identifier == Self.showUseCaseListSegueIdentifier, let destination = segue.destination as? UseCaseListViewController {
            destination.configure(with: mainMenuDataSource?.currentUseCase)
        }
    }
    
    @IBAction func unwindFromList(unwindSegue: UIStoryboardSegue) {
        
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        guard persistentContainer != nil else {
//            fatalError("This view needs a persistent container.")
//        }
        if mainMenuDataSource?.currentUseCase == nil {
            configure(with: nil)
        }
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//    }
    
    // MARK: - Actions
    
    @IBAction func addButtonTriggered(_ sender: UIButton) {
        addUseCase()
    }
    
    // MARK: - Use Case View
    
    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        guard let context = mainMenuDataSource?.persistentContainer.viewContext else { return }
        let useCase = UseCase(context: context)
        useCase.date = Date()
        useCase.id = UUID()
        detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
            self.mainMenuDataSource?.add(useCase, completion: { success in
                if success {
                    self.mainMenuDataSource?.updateCurrentUseCase(useCase)
                }
            })
        })
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    private func refreshUseCaseView(title: String?, subjectID: String?) {
        useCaseView.configure(title: title, subjectIDText: subjectID)
    }
    
}
