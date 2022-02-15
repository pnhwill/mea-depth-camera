//
//  ModelStore.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import Foundation

// MARK: ModelStore Protocol
/// Generic model store for quick lookup of `Identifiable` models.
protocol ModelStore {
    associatedtype Model: Identifiable
    /// Fetches the stored model by its identifier.
    func fetchByID(_ id: Model.ID) -> Model?
}

// MARK: AnyModelStore
/// Basic `ModelStore` implementation for static model collections.
class AnyModelStore<Model: Identifiable>: ModelStore {
    private var models = [Model.ID: Model]()
    init(_ models: [Model]) {
        self.models = models.groupingByUniqueID()
    }
    func fetchByID(_ id: Model.ID) -> Model? {
        return self.models[id]
    }
}

// MARK: ListModelStore
/// A `ModelStore` implementation with additional methods for changing the underlying model collection.
class ListModelStore<Model: Identifiable>: ModelStore {
    private var models = [Model.ID: Model]()
    init(_ models: [Model]) {
        self.models = models.groupingByUniqueID()
    }
    func fetchByID(_ id: Model.ID) -> Model? {
        return self.models[id]
    }
    /// Reinitializes the model store with the given models.
    func reload(with newModels: [Model]) {
        models = newModels.groupingByUniqueID()
    }
    /// Merges the given models into the store, replacing models that have duplicate IDs with the new values.
    func merge(newModels: [Model]) {
        models.merge(newModels.groupingByUniqueID()) { (_, new) in new }
    }
    /// Deletes the model with the given ID from the store.
    func deleteByID(_ id: Model.ID) {
        models.removeValue(forKey: id)
    }
}

// MARK: ObservableModelStore
/// Concrete `ModelStore` class that conforms to `ObservableObject` and has a `@Published` model dictionary property.
class ObservableModelStore<Model: Identifiable>: ModelStore, ObservableObject {

    /// `@Published` dictionary containing the stored models keyed by their identifiers.
    @Published private(set) var allModels = [Model.ID: Model]()
    
    init(_ models: [Model]) {
        self.allModels = models.groupingByUniqueID()
    }
    
    func fetchByID(_ id: Model.ID) -> Model? {
        return self.allModels[id]
    }
    /// Reinitializes the model store with the given models.
    func reload(with newModels: [Model]) {
        allModels = newModels.groupingByUniqueID()
    }
    /// Merges the given models into the store, replacing models that have duplicate IDs with the new values.
    func merge(newModels: [Model]) {
        allModels.merge(newModels.groupingByUniqueID()) { (_, new) in new }
    }
    /// Deletes the model with the given ID from the store.
    func deleteByID(_ id: Model.ID) {
        allModels.removeValue(forKey: id)
    }
}
