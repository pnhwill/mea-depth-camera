//
//  UseCaseDetailViewDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class UseCaseDetailViewDataSource: NSObject {
    
    enum UseCaseRow: Int, CaseIterable {
        case title
        case date
        case subjectID
        case numRecordings
        case notes
        
        static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()
        
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateStyle = .long
            return formatter
        }()
        
        func displayText(for useCase: UseCase) -> String? {
            switch self {
            case .title:
                return useCase.title
            case .date:
                guard let date = useCase.date else { return nil }
                let timeText = Self.timeFormatter.string(from: date)
                if Locale.current.calendar.isDateInToday(date) {
                    return UseCase.todayDateFormatter.string(from: date)
                }
                return Self.dateFormatter.string(from: date) + " at " + timeText
            case .subjectID:
                guard let subjectID = useCase.subjectID else { return nil }
                return "Subject ID: " + subjectID
            case .numRecordings:
                return String(useCase.recordingsCount) + " Recordings"
            case .notes:
                return useCase.notes
            }
        }
        
    }
    
    private var useCase: UseCase
    
    init(useCase: UseCase) {
        self.useCase = useCase
        super.init()
    }
}

extension UseCaseDetailViewDataSource: UITableViewDataSource {
    static let useCaseDetailCellIdentifier = "UseCaseDetailCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UseCaseRow.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.useCaseDetailCellIdentifier, for: indexPath)
        let row = UseCaseRow(rawValue: indexPath.row)
        cell.textLabel?.text = row?.displayText(for: useCase)
        //cell.imageView?.image = row?.cellImage
        return cell
    }
    
    
    
    
}
