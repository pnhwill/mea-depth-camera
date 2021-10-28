//
//  TextFieldCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

class TextFieldCell: UICollectionViewListCell {
    
    let textField = UITextField()
    
    weak var delegate: TextInputCellDelegate?
    var indexPath: IndexPath!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpInternalViews()
        configureTextField()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with initialText: String?, at indexPath: IndexPath, delegate: TextInputCellDelegate? = nil) {
        textField.text = initialText
        self.indexPath = indexPath
        self.delegate = delegate
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        let defaultConfiguration = defaultContentConfiguration().updated(for: state)
        textField.font = defaultConfiguration.textProperties.font
        textField.textColor = defaultConfiguration.textProperties.resolvedColor()
    }
}

extension TextFieldCell {
    private func setUpInternalViews() {
        contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    private func configureTextField() {
        textField.delegate = self
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .asciiCapable
    }
}

extension TextFieldCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let originalText = textField.text {
            let newText = (originalText as NSString).replacingCharacters(in: range, with: string)
            delegate?.textChangedAt(indexPath: indexPath, replacementString: newText)
        }
        return true
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
