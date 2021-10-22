//
//  UseCaseListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit

class UseCaseListCell: ItemListCell {
    
//    static let reuseIdentifier = "UseCaseListCell"
    
    private func defaultListContentConfiguration() -> UIListContentConfiguration { return .cell() }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        guard let useCase = state.item?.object as? UseCase else { fatalError() }
        
        guard let titleText = useCase.title else { return }
        let dateText = "date"
        let subjectIDText = "Subject ID: 123"
        let experimentText = "experiment title"
        let recordedTasksText = "number of tasks recorded out of total"
        let bodyText = [[dateText, subjectIDText], [experimentText, recordedTasksText]]
        
        let content = TextCellContentConfiguration(titleText: titleText, bodyText: bodyText)
        
        contentConfiguration = content
    }
}

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



class OldUseCaseListCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var subjectIDLabel: UILabel!
    @IBOutlet weak var numRecordingsLabel: UILabel!

    func configure(title: String?, dateText: String?, subjectIDText: String?, recordingsCountText: String) {
        titleLabel.text = title
        dateLabel.text = dateText
        if let subjectIDText = subjectIDText {
            subjectIDLabel.text = "Subject ID: " + subjectIDText
        }
        numRecordingsLabel.text = recordingsCountText
    }
}

