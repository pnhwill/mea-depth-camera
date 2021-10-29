//
//  ModelStore.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//
/*
Abstract:
Generic model store for quick lookup of Identifiable models.
*/

import Foundation

protocol ModelStore {
    associatedtype Model: Identifiable
    
    func fetchByID(_ id: Model.ID) -> Model?
}

class AnyModelStore<Model: Identifiable>: ModelStore {
    
    private var models = [Model.ID: Model]()
    
    init(_ models: [Model]) {
        self.models = models.groupingByUniqueID()
    }
    
    func fetchByID(_ id: Model.ID) -> Model? {
        return self.models[id]
    }
}

extension Sequence where Element: Identifiable {
    func groupingByID() -> [Element.ID: [Element]] {
        return Dictionary(grouping: self, by: { $0.id })
    }
    
    func groupingByUniqueID() -> [Element.ID: Element] {
        return Dictionary(uniqueKeysWithValues: self.map { ($0.id, $0) })
    }
}
