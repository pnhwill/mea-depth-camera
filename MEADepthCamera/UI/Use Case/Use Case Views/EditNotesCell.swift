//
//  EditNotesCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/12/21.
//

import UIKit

class EditNotesCell: UITableViewCell {
    typealias NotesChangeAction = (String) -> Void
    
    @IBOutlet var notesTextView: UITextView!
    
    private var notesChangeAction: NotesChangeAction?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        notesTextView.delegate = self
    }
    
    func configure(notes: String?, changeAction: NotesChangeAction?) {
        notesTextView.text = notes
        self.notesChangeAction = changeAction
    }
}

extension EditNotesCell: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let originalText = textView.text {
            let notes = (originalText as NSString).replacingCharacters(in: range, with: text)
            notesChangeAction?(notes)
        }
        return true
    }
}

