//
//  TextInputCellDelegate.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

protocol TextInputCellDelegate: AnyObject {
    
    func textChangedAt(indexPath: IndexPath, replacementString string: String)
    
}
