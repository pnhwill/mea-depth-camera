//
//  TaskDetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import Foundation

class TaskDetailViewModel: ListViewModel {
    
    var sectionsStore: ObservableModelStore<Section>?
    var itemsStore: ObservableModelStore<Item>?
    
    private var useCase: UseCase
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    
    
    
}
