//
//  UseCaseListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit

class NewUseCaseListCell: ItemListCell {
    
    static let reuseIdentifier = "UseCaseListCell"
    
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let subjectIDLabel = UILabel()
    private let experimentLabel = UILabel()
    private let recordedTasksCountLabel = UILabel()
    
    private func defaultListContentConfiguration() -> UIListContentConfiguration { return .subtitleCell() }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        guard let useCase = state.item?.object as? UseCase else { return }
        
        var titleContent = defaultListContentConfiguration()
        titleContent.text = useCase.title
        
//        var dateContent =
        
        let bodyContent = [[UIListContentConfiguration.subtitleCell()]]
        let content = ListContentConfiguration(titleConfiguration: titleContent, bodyConfigurations: bodyContent, buttonConfigurations: nil)
        contentConfiguration = content
    }
}





class UseCaseListCell: UITableViewCell {
    
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





