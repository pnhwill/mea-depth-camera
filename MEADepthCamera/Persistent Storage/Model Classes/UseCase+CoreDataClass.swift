//
//  UseCase+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//
//

import Foundation
import CoreData
import UIKit

@objc(UseCase)
public class UseCase: NSManagedObject {

    
    func recordingsCount(for task: Task) -> Int {
        let recordings = recordings as! Set<Recording>
        return recordings.reduce(0) { $0 + ($1.task == task ? 1 : 0) }
    }
}

extension UseCase: ModelObject {
    func listContentConfiguration() -> ListContentConfiguration {
        let titleContent = UIListContentConfiguration.subtitleCell()
        let bodyContent = [[UIListContentConfiguration.subtitleCell()]]
        return ListContentConfiguration(titleConfiguration: titleContent, bodyConfigurations: bodyContent, buttonConfigurations: nil)
    }
}

// MARK: Text Formatters
extension UseCase {
    func recordingsCountText() -> String {
        switch recordingsCount {
        case 1:
            return String(recordingsCount) + " Recording"
        default:
            return String(recordingsCount) + " Recordings"
        }
    }
}
