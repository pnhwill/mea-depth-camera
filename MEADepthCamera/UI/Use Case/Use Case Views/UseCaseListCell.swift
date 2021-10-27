//
//  UseCaseListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit

class UseCaseListCell: ItemListCell {
    
    weak var delegate: UseCaseInteractionDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAccessories()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: updateConfiguration(using:)
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let useCase = state.item?.object as? UseCase else { fatalError() }
        
        guard let titleText = useCase.title,
              let experimentText = useCase.experimentTitle,
              let dateText = useCase.dateTimeText(for: .all),
              let subjectID = useCase.subjectID
        else { return }
        let subjectIDText = "Subject ID: " + subjectID
        let recordedTasksText = "X out of X tasks completed"
        let bodyText = [subjectIDText, dateText, recordedTasksText]
        let content = TextCellContentConfiguration(titleText: titleText, subtitleText: experimentText, bodyText: bodyText)
        contentConfiguration = content
    }
    
    private func configureAccessories() {
        let disclosure = UICellAccessory.disclosureIndicator()
        let delete = UICellAccessory.delete() { self.deleteAction() }
        accessories = [delete, disclosure]
    }
    
    private func deleteAction() {
        guard let useCase = configurationState.item?.object as? UseCase else { fatalError() }
        delegate?.delete(useCase)
    }
}





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

