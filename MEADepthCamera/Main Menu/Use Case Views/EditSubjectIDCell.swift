//
//  EditSubjectIDCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class EditSubjectIDCell: UITableViewCell {
    typealias SubjectIDChangeAction = (String) -> Void
    
    @IBOutlet var subjectIDTextField: UITextField!
    
    private var subjectIDChangeAction: SubjectIDChangeAction?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        subjectIDTextField.delegate = self
    }
    
    func configure(subjectID: String?, changeAction: @escaping SubjectIDChangeAction) {
        subjectIDTextField.text = subjectID
        self.subjectIDChangeAction = changeAction
    }
}

extension EditSubjectIDCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let originalText = textField.text {
            let subjectID = (originalText as NSString).replacingCharacters(in: range, with: string)
            subjectIDChangeAction?(subjectID)
        }
        return true
    }
}
