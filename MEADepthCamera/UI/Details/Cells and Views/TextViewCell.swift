//
//  TextViewCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

class TextViewCell: UICollectionViewListCell {
    
    let textView = UITextView()
    
    weak var delegate: TextInputCellDelegate?
    var indexPath: IndexPath!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpInternalViews()
        configureTextView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with initialText: String?, at indexPath: IndexPath, delegate: TextInputCellDelegate? = nil) {
        textView.text = initialText
        self.indexPath = indexPath
        self.delegate = delegate
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        let defaultConfiguration = defaultContentConfiguration().updated(for: state)
        textView.font = defaultConfiguration.textProperties.font
        textView.textColor = defaultConfiguration.textProperties.resolvedColor()
    }
}

extension TextViewCell {
    private func setUpInternalViews() {
        contentView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
//            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 194)
        ])
    }
    private func configureTextView() {
        textView.delegate = self
        textView.returnKeyType = .done
        textView.keyboardType = .asciiCapable
        textView.autocapitalizationType = .sentences
        textView.backgroundColor = .clear
    }
}

extension TextViewCell: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let originalText = textView.text {
            let newText = (originalText as NSString).replacingCharacters(in: range, with: text)
            delegate?.textChangedAt(indexPath: indexPath, replacementString: newText)
        }
        return true
    }
}

