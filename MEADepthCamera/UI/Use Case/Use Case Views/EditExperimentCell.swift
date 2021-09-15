//
//  EditExperimentCell.swift
//  MEADepthCamera
//
//  Created by Will on 9/8/21.
//

import UIKit

class EditExperimentCell: UITableViewCell {
    
    @IBOutlet var pickerView: UIPickerView!
    
    func configure(dataSource: UIPickerViewDataSource, delegate: UIPickerViewDelegate) {
        pickerView.dataSource = dataSource
        pickerView.delegate = delegate
        pickerView.selectRow(0, inComponent: 0, animated: true)
    }
    
}
