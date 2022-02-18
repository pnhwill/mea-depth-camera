//
//  AboutViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 12/13/21.
//

import Foundation

protocol CaseIdentifiable {
    associatedtype Item: Hashable, CaseIterable
}

protocol CaseSubtitleRepresentable: CaseIdentifiable {
    var subtitles: [Item: String] { get }
}

protocol SubtitleTextRepresentable {
    var subtitleText: [String: String] { get }
}

extension SubtitleTextRepresentable where Self: CaseSubtitleRepresentable, Item: RawRepresentable, Item.RawValue == String {
    var subtitleText: [String: String] {
        Dictionary(uniqueKeysWithValues: subtitles.map { ($0.key.rawValue, $0.value) })
    }
}

/// View model for the app's "About" view.
class AboutViewModel: NavigationTitleProviding {
    
    struct AboutSection: Hashable {
        let title: String
        let items: [AboutItem]
        
        init(title: String, item: SubtitleTextRepresentable) {
            self.title = title
            self.items = item.subtitleText.map { AboutItem(title: $0.key, subtitle: $0.value) }
        }
    }
    
    struct AboutItem: Hashable {
        let title: String
        let subtitle: String
    }
    
    // MARK: AboutInfo Model
    /// The data model for the app's "About" information.
    struct AboutInfo: Codable {
        /// AboutInfo's three different categories.
        enum Section: String, CaseIterable {
            case author = "Author"
            case version = "Version"
            case source = "Source Code"
        }
        /// Model for AboutInfo's author information.
        struct Author: Codable, SubtitleTextRepresentable, CaseSubtitleRepresentable {
            enum Item: String, CaseIterable {
                case name = "Name"
                case email = "Email"
            }
            let name: String
            let email: String
            
            var subtitles: [Item: String] { [.name: name, .email: email] }
        }
        /// Model for AboutInfo's version information.
        struct Version: Codable, SubtitleTextRepresentable, CaseSubtitleRepresentable {
            enum Item: String, CaseIterable {
                case stage = "Stage"
                case number = "Number"
                case build = "Build"
                case date = "Date"
            }
            let stage: String
            let number: String
            let build: String
            let date: String
            
            var subtitles: [Item: String] { [.stage: stage, .number: number, .build: build, .date: date] }
        }
        /// Model for AboutInfo's source code information.
        struct Source: Codable, SubtitleTextRepresentable, CaseSubtitleRepresentable {
            enum Item: String, CaseIterable {
                case link = "Link"
                case license = "License"
            }
            let link: String
            let license: String
            
            var subtitles: [Item: String] { [.link: link, .license: license] }
        }
        
        var aboutSections: [AboutSection] {
            sections.map { AboutSection(title: $0.key.rawValue, item: $0.value) }
        }
        
        private let author: Author
        private let version: Version
        private let source: Source
        
        private var sections: [Section: SubtitleTextRepresentable] { [.author: author, .version: version, .source: source] }
    }
    
    let aboutInfo: AboutInfo
    
    let navigationTitle: String = "About \(Bundle.main.applicationName)"
    
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
