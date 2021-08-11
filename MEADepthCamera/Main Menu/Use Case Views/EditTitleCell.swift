//
//  EditTitleCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class EditTitleCell: UITableViewCell {
    typealias TitleChangeAction = (String) -> Void
    
    @IBOutlet var titleTextField: UITextField!
    
    private var titleChangeAction: TitleChangeAction?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleTextField.delegate = self
    }
    
    func configure(title: String, changeAction: @escaping TitleChangeAction) {
        titleTextField.text = title
        self.titleChangeAction = changeAction
    }
}

extension EditTitleCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let originalText = textField.text {
            let title = (originalText as NSString).replacingCharacters(in: range, with: string)
            titleChangeAction?(title)
        }
        return true
    }
}
