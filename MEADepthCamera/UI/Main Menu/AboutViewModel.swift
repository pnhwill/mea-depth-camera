//
//  AboutViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 12/13/21.
//

import Foundation

/// ListViewModel for the app's "About" view.
class AboutViewModel: ListViewModel {
    
    // MARK: AboutInfo Model
    /// The data model for the app's "About" information.
    private struct AboutInfo: Codable, OutlineItemArrayConvertible {
        /// Model for AboutInfo's three info categories.
        enum Item: String, CaseIterable, DictionaryIdentifiable {
            case author = "Author"
            case version = "Version"
            case source = "Source Code"
            
            static let identifiers = newIdentifierDictionary()
        }
        /// Model for AboutInfo's author information.
        struct Author: Codable, SubtitleItemArrayConvertible {
            enum Item: String, CaseIterable, DictionaryIdentifiable {
                case name = "Name"
                case email = "Email"
                
                static let identifiers = newIdentifierDictionary()
            }
            let name: String
            let email: String
            
            var subtitleText: [Item: String] { [.name: name, .email: email] }
        }
        /// Model for AboutInfo's version information.
        struct Version: Codable, SubtitleItemArrayConvertible {
            enum Item: String, CaseIterable, DictionaryIdentifiable {
                case stage = "Stage"
                case number = "Number"
                case build = "Build"
                case date = "Date"
                
                static let identifiers = newIdentifierDictionary()
            }
            let stage: String
            let number: String
            let build: String
            let date: String
            
            var subtitleText: [Item: String] { [.stage: stage, .number: number, .build: build, .date: date] }
        }
        /// Model for AboutInfo's source code information.
        struct Source: Codable, SubtitleItemArrayConvertible {
            enum Item: String, CaseIterable, DictionaryIdentifiable {
                case link = "Link"
                case license = "License"

                static let identifiers = newIdentifierDictionary()
            }
            let link: String
            let license: String
            
            var subtitleText: [Item: String] { [.link: link, .license: license] }
        }
        
        let author: Author
        let version: Version
        let source: Source
        
        var subItems: [Item: ListItemArrayConvertible] { [.author: author, .version: version, .source: source] }
    }
    
    // MARK: Model Stores
    private(set) lazy var sectionsStore: ObservableModelStore<Section>? = {
        let section = ListSection(id: .header, items: headerListItemIds)
        return ObservableModelStore([section])
    }()
    private(set) lazy var itemsStore: ObservableModelStore<Item>? = {
        ObservableModelStore(allListItems)
    }()
    
    private var aboutInfo: AboutInfo
    
    private let titleListItem = ListItem(id: UUID(), title: "About MEADepthCamera")
    
    private var allListItems: [ListItem] {
        [[titleListItem],
         aboutInfo.listItems,
         aboutInfo.author.listItems,
         aboutInfo.version.listItems,
         aboutInfo.source.listItems].flatMap { $0 }
    }
    private var headerListItemIds: [UUID] { [[titleListItem.id], AboutInfo.Item.allCases.map { $0.id }].flatMap { $0 } }
    
    init() {
        let aboutInfo: [AboutInfo] = load("about.json")
        self.aboutInfo = aboutInfo[0]
    }
    
}

// MARK: Load JSON Data
/// Generic JSON decoder function for loading data from a file.
func load<T: Decodable>(_ filename: String) -> T {
    let data: Data
    
    guard let file = Bundle.main.url(forResource: filename, withExtension: nil)
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }
    
    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }
    
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}
