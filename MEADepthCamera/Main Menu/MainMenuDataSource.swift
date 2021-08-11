//
//  MainMenuDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class MainMenuDataSource: NSObject {
    typealias CurrentUseCaseChangedAction = (SavedUseCase?) -> Void
    
    var currentUseCase: SavedUseCase?
    private var currentUseCaseChangedAction: CurrentUseCaseChangedAction?
    
    init(currentUseCaseChangedAction: @escaping CurrentUseCaseChangedAction) {
        self.currentUseCaseChangedAction = currentUseCaseChangedAction
    }
    
    func updateCurrentUseCase(_ useCase: SavedUseCase?) {
        currentUseCase = useCase
        currentUseCaseChangedAction?(currentUseCase)
    }
    
}
