//
//  AppDelegate.swift
//  MEADepthCamera
//
//  Created by Will on 7/13/21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let shared: AppDelegate = {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("Unexpected app delegate type, did it change? \(String(describing: UIApplication.shared.delegate))")
        }
        return delegate
    }()
    
    lazy var coreDataStack: CoreDataStack = { return CoreDataStack() }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Asynchronously load the stored JSON data into the Core Data store
        _Concurrency.Task {
            await fetchExperiments()
        }
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Self.shared.coreDataStack.persistentContainer.saveContext()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    private func fetchExperiments() async {
        // Core Data provider to load experiments
        let container = coreDataStack.persistentContainer
        let provider = ExperimentProvider(with: container, fetchedResultsControllerDelegate: nil)
        
        do {
            try await provider.fetchJSONData()
        } catch {
            let error = error as? JSONError ?? .unexpectedError(error: error)
            fatalError("Failed to fetch experiments: \(error)")
        }
    }
}

