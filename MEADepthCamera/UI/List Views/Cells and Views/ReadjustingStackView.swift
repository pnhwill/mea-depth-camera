//
//  ReadjustingStackView.swift
//  MEADepthCamera
//
//  Created by Will on 10/19/21.
//
/*
Abstract:
A custom stack view class that automatically adjusts its orientation as needed to fit the content inside without truncation.
*/

import UIKit

class ReadjustingStackView: UIStackView {
    
    // The size of our margins, i.e. the the constant value of the leading space constraint to the superview.
    var marginSize: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // We want to recalculate our orientation whenever the dynamic type settings on the device change
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustOrientation),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // This takes care of recalculating our orientation whenever our content or layout changes
    // (such as due to device rotation, addition of more buttons to the stack view, etc).
    override func layoutSubviews() {
        super.layoutSubviews()
        adjustOrientation()
    }
    
    @objc
    func adjustOrientation() {
        
        // Always attempt to fit everything horizontally first
        axis = .horizontal
        alignment = .firstBaseline
        distribution = .fillEqually
        
        let desiredStackViewWidth = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        if let parent = superview {
            let availableWidth = parent.bounds.inset(by: parent.safeAreaInsets).width - (marginSize * 2.0)
            if desiredStackViewWidth > availableWidth {
                axis = .vertical
                alignment = .fill
                distribution = .fill
            }
        }
    }
}


/*
struct StackListContentConfiguration: UIContentConfiguration, Equatable {
    
    var subContent: [UIContentConfiguration]
    var isStackViewDynamic: Bool = true
    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal
    
    private let identifier = UUID()
    
    static func == (lhs: StackListContentConfiguration, rhs: StackListContentConfiguration) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func makeContentView() -> UIView & UIContentView {
        if subContent.count == 1 {
            return subContent[0].makeContentView()
        } else {
            return StackListContentView(configuration: self)
        }
    }
    
    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        updatedConfiguration.subContent = subContent.map { $0.updated(for: state) }
        return updatedConfiguration
    }
}

class StackListContentView: UIView, UIContentView {
    
    private lazy var stackView = ReadjustingStackView()
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? StackListContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private var appliedConfiguration: StackListContentConfiguration!
    
    init(configuration: StackListContentConfiguration) {
        super.init(frame: .zero)
        setupInternalViews()
        apply(configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupInternalViews() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    private func apply(configuration: StackListContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        for config in configuration.subContent {
            let newView = config.makeContentView()
            
//            newView.translatesAutoresizingMaskIntoConstraints = false
//
            if let listContentView = newView as? UIListContentView {
                guard let textLayoutGuide = listContentView.textLayoutGuide else { fatalError() }

                NSLayoutConstraint.activate([
                    listContentView.heightAnchor.constraint(equalTo: textLayoutGuide.heightAnchor)
                ])
            }
            stackView.addArrangedSubview(newView)
        }
//        stackView.readjustingEnabled = configuration.isStackViewDynamic
//        stackView.desiredAxis = configuration.stackViewAxis
//        stackView.isHidden = false
        
        //            let stackView = UIStackView(arrangedSubviews: rowLabels)
        //            stackView.translatesAutoresizingMaskIntoConstraints = false
        //            stackView.axis = .vertical
        //            stackView.distribution = .fill
        //            stackView.alignment = .fill
        //            stackView.spacing = listConfig.textToSecondaryTextVerticalPadding
        //            stackView.isLayoutMarginsRelativeArrangement = true
        //            stackView.directionalLayoutMargins = listConfig.directionalLayoutMargins
        //            stackView.directionalLayoutMargins.top = listConfig.textToSecondaryTextVerticalPadding
        //            bodyStackView.addArrangedSubview(stackView)
    }
}
*/

//var titleContent = defaultContentConfiguration().updated(for: state)
//titleContent.text = useCase.title
//
//var dateContent = defaultContentConfiguration().updated(for: state)
//dateContent.text = "date"
//
//var subjectIDContent = defaultContentConfiguration().updated(for: state)
//subjectIDContent.text = "subject ID"
//
//let firstStack = StackListContentConfiguration(subContent: [dateContent, subjectIDContent], isStackViewDynamic: false, stackViewAxis: .vertical).updated(for: state)
//
//var experimentContent = defaultContentConfiguration().updated(for: state)
//experimentContent.text = "experiment title"
//
//var recordedTasksContent = defaultContentConfiguration().updated(for: state)
//recordedTasksContent.text = "number of tasks recorded out of total"
//
//let secondStack = StackListContentConfiguration(subContent: [experimentContent, recordedTasksContent], isStackViewDynamic: false, stackViewAxis: .vertical).updated(for: state)
//
//let bodyContent = StackListContentConfiguration(subContent: [firstStack, secondStack], isStackViewDynamic: false, stackViewAxis: .vertical).updated(for: state)
//
//let content = StackListContentConfiguration(subContent: [titleContent, bodyContent], isStackViewDynamic: false, stackViewAxis: .vertical).updated(for: state)
