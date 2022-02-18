//
//  UseCaseProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData

/// A class to wrap everything related to fetching, creating, and deleting use cases.
final class UseCaseProvider: DataFetcher<UseCase>, ListDataProvider {
    
    typealias Object = UseCase
    
    override var sortKeyPaths: [String]? {
        [Schema.UseCase.title.rawValue]
    }
    
//    override var sectionNameKeyPath: String? {
//        Schema.Entity.isDefaultString.rawValue
//    }

}
