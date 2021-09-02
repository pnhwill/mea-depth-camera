//
//  OutputFileProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/2/21.
//
/*
Abstract:
A class to wrap everything related to creating, and deleting output files, and saving and deleting file data.
*/

import CoreData

class OutputFileProvider: DataProvider {
    
    typealias Entity = OutputFile
    
    private(set) var persistentContainer: PersistentContainer
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
}
