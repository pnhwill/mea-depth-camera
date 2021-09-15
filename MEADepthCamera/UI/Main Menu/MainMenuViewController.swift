//
//  MainMenuViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import CoreData

class MainMenuViewController: UIViewController {
    
    @IBOutlet private weak var useCaseView: UseCaseSummaryView!
    @IBOutlet private weak var addUseCaseButton: UIButton!
    @IBOutlet private weak var useCaseListButton: UIButton!
    @IBOutlet private weak var startButton: UIButton!
    
    static let showRecordingListSegueIdentifier = "ShowRecordingListSegue"
    static let showUseCaseListSegueIdentifier = "ShowUseCaseListSegue"
    static let unwindFromListSegueIdentifier = "UnwindFromUseCaseListSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var dataSource: MainMenuDataSource?
    
    // MARK: - Navigation
    
    func configure(with useCase: UseCase?) {
        dataSource?.didUpdateUseCase(useCase)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showRecordingListSegueIdentifier, let destination = segue.destination as? RecordingListViewController {
            guard let useCase = dataSource?.useCase else {
                fatalError("Couldn't find data source for use case.")
            }
            destination.configure(with: useCase)
        }
        if segue.identifier == Self.showUseCaseListSegueIdentifier, let destination = segue.destination as? UseCaseListViewController {
            destination.configure(with: dataSource?.useCase)
        }
    }
    
    @IBAction func unwindFromList(unwindSegue: UIStoryboardSegue) {
        
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = MainMenuDataSource(useCaseChangedAction: {
            DispatchQueue.main.async {
                self.refreshUI()
            }
        })
        refreshUI()
        self.navigationItem.setHidesBackButton(true, animated: false)
    }
    
    // MARK: - Actions
    
    @IBAction func addButtonTriggered(_ sender: UIButton) {
        addUseCase()
    }
    
    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        dataSource?.add() { useCase in
            detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
                self.dataSource?.saveUseCase(useCase) { success in
                    if success {
                        self.dataSource?.didUpdateUseCase(useCase)
                    }
                }
            })
        }
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - Use Case View
    
    private func refreshUI() {
        if let useCase = dataSource?.useCase {
            let titleText = [useCase.experiment?.title, useCase.title].compactMap { $0 }.joined(separator: ": ")
            useCaseView.configure(title: titleText, subjectIDText: useCase.subjectID)
            startButton.isEnabled = true
        } else {
            useCaseView.configure(title: "No Use Case Selected", subjectIDText: nil)
            startButton.isEnabled = false
        }
    }
    
}
