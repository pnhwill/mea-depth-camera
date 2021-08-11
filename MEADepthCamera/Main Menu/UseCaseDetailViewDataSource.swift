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
        case subjectID
        
        func displayText(for useCase: UseCase?) -> String? {
            switch self {
            case .title:
                return useCase?.title
            case .subjectID:
                return useCase?.subjectID
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
