//
//  ObservableModelStore.swift
//  MEADepthCamera
//
//  Created by Will on 10/28/21.
//

import Foundation

class ObservableModelStore<Model: Identifiable>: ModelStore, ObservableObject {

    @Published private(set) var allModels = [Model.ID: Model]()
    
    init(_ models: [Model]) {
        self.allModels = models.groupingByUniqueID()
    }
    
    func fetchByID(_ id: Model.ID) -> Model? {
        return self.allModels[id]
    }
    
    func reload(with newModels: [Model]) {
        allModels = newModels.groupingByUniqueID()
    }
    
    func add(newModels: [Model]) {
        allModels.merge(newModels.groupingByUniqueID()) { (_, new) in new }
    }
    
    func delete(_ models: [Model]) {
        models.forEach { allModels.removeValue(forKey: $0.id) }
    }
    
    func deleteByID(_ id: Model.ID) {
        allModels.removeValue(forKey: id)
    }
}
