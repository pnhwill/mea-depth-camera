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
    @IBOutlet private weak var startButton: UIButton!
    
    static let showCameraSegueIdentifier = "ShowCameraSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    private var mainMenuDataSource: MainMenuDataSource?
    
    // Core Data persistent container
    private lazy var persistentContainer: PersistentContainer? = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate?.persistentContainer
    }()
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showCameraSegueIdentifier, let destination = segue.destination as? CameraViewController {
            destination.persistentContainer = persistentContainer
            guard let useCase = mainMenuDataSource?.currentUseCase else {
                fatalError("Couldn't find data source for use case.")
            }
            destination.useCase = useCase
        }
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard persistentContainer != nil else {
            fatalError("This view needs a persistent container.")
        }
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
        startButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainMenuDataSource?.updateCurrentUseCase(nil)
    }
    
    // MARK: - Actions
    
    @IBAction func addButtonTriggered(_ sender: UIButton) {
        addUseCase()
    }
    
    // MARK: - Use Case View
    
    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: UseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        let useCase = SavedUseCase(id: UUID(), title: "New Use Case", date: Date(), subjectID: "", recordings: [])
        detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
            self.mainMenuDataSource?.updateCurrentUseCase(useCase)
        })
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    private func refreshUseCaseView(title: String, subjectID: String?) {
        useCaseView.configure(title: title, subjectIDText: subjectID)
    }
    
}
