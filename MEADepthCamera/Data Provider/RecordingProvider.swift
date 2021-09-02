//
//  RecordingProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to wrap everything related to creating and deleting recordings.
*/

import CoreData

class RecordingProvider: DataProvider {
    
    typealias Entity = Recording
    
    private(set) var persistentContainer: PersistentContainer
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
}
