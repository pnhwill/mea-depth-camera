//
//  PickerViewCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

class PickerViewCell: UICollectionViewListCell {
    
    let pickerView = UIPickerView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpInternalViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(dataSource: UIPickerViewDataSource, delegate: UIPickerViewDelegate) {
        pickerView.dataSource = dataSource
        pickerView.delegate = delegate
        // Select the first row by default after the delegate is set so that delegate method pickerView(_:didSelectRow:inComponent:) is called.
        pickerView.selectRow(0, inComponent: 0, animated: true)
        delegate.pickerView?(pickerView, didSelectRow: 0, inComponent: 0)
    }
}

extension PickerViewCell {
    private func setUpInternalViews() {
        contentView.addSubview(pickerView)
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        let inset = CGFloat(40)
        NSLayoutConstraint.activate([
            pickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pickerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -inset),
            pickerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: inset)
        ])
    }
}
