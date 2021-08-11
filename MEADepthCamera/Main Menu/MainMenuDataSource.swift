//
//  MainMenuDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class MainMenuDataSource: NSObject {
    typealias CurrentUseCaseChangedAction = (UseCase?) -> Void
    
    private var currentUseCase: UseCase?
    private var currentUseCaseChangedAction: CurrentUseCaseChangedAction?
    
    init(currentUseCaseChangedAction: @escaping CurrentUseCaseChangedAction) {
        self.currentUseCaseChangedAction = currentUseCaseChangedAction
    }
    
    func updateCurrentUseCase(_ useCase: UseCase?) {
        currentUseCase = useCase
        currentUseCaseChangedAction?(currentUseCase)
    }
    
}
