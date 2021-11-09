//
//  BackButton.swift
//  MEADepthCamera
//
//  Created by Will on 11/8/21.
//

import UIKit

class BackButton: UIBarButtonItem {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        let button = UIButton(type: .system)
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.contentInsets.leading = .zero
        buttonConfiguration.imagePadding = CGFloat(6)
        button.configuration = buttonConfiguration
        let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
        let image = UIImage(systemName: "chevron.backward", withConfiguration: symbolConfiguration)
        button.setImage(image, for: .normal)
        button.setTitle(title, for: .normal)
        button.sizeToFit()
        customView = button
    }
}
