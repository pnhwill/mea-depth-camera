//
//  FaceGuideView.swift
//  MEADepthCamera
//
//  Created by Will on 12/9/21.
//

import UIKit

/// Container view for a UIImageView that displays the face alignment guide and updates the color of the guide when needed.
class FaceGuideView: UIView {
    
    /// Enumeration for the three possible states of the face guide image which we use to update the image.
    enum OutlineColor {
        case red, green, white
        
        static let redImage = UIImage(named: "face_outline_red")
        static let greenImage = UIImage(named: "face_outline_green")
        static let whiteImage = UIImage(named: "face_outline_white")
        
        var image: UIImage? {
            switch self {
            case .red:
                return Self.redImage
            case .green:
                return Self.greenImage
            case .white:
                return Self.whiteImage
            }
        }
        
        var alpha: CGFloat {
            switch self {
            case .red:
                return 0.8
            case .green:
                return 0.8
            case .white:
                return 0.4
            }
        }
    }
    
    /// The current outline color of the face guide image.
    ///
    /// Setting this property automatically updates the image view using the new value.
    var outlineColor: OutlineColor = .white {
        didSet {
            updateImageView()
        }
    }
    
    private let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        addSubview(imageView)
        imageView.bindEdgesToSuperview()
        imageView.contentMode = .scaleAspectFit
        updateImageView()
    }
    
    private func updateImageView() {
        imageView.image = outlineColor.image
        imageView.alpha = outlineColor.alpha
    }
}
