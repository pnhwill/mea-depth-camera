//
//  ButtonSupplementaryView.swift
//  MEADepthCamera
//
//  Created by Will on 11/3/21.
//

import UIKit

class ButtonSupplementaryView: UICollectionReusableView {
    
    typealias ButtonAction = () -> Void
    
    let button = UIButton(configuration: .filled())
    
    private var buttonAction: ButtonAction?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
        configureButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setButtonAction(buttonAction: @escaping ButtonAction) {
        self.buttonAction = buttonAction
    }
    
    @objc
    func startButtonTapped() {
        // Show the task list
        buttonAction?()
    }
}

extension ButtonSupplementaryView {
    private func setUpViews() {
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            button.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            button.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    private func configureButton() {
        button.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        button.tintColor = .systemGreen
        // TODO: set the font of the button title (line below should work but doesn't)
//        button.titleLabel?.font = .preferredFont(forTextStyle: .largeTitle)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setTitle("Start", for: .normal)
    }
}
