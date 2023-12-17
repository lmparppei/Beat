//
//  BeatTitlePage.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 17.12.2023.
//

import Foundation
import BeatParsing

@objc public class BeatTitlePage:NSObject {
    
    var titlePageLines:[[String:[Line]]] = []
    
    @objc public init(_ titlePage:[[String:[Line]]]) {
        self.titlePageLines = titlePage
        super.init()
    }
    
    func get(_ key:String, andRemove remove:Bool = false) -> [Line]? {
        var lines:[Line] = []

        for i in 0..<titlePageLines.count {
            let dict = titlePageLines[i]
            
            if (dict[key] != nil) {
                lines = dict[key] ?? []
                if (remove) { titlePageLines.remove(at: i) }
                break
            }
        }
        
        // No title page element was found, return nil
        if lines.count == 0 { return [] }
    
        var type:LineType = .empty
        switch key {
            case "title":
                type = .titlePageTitle
            case "authors":
                type = .titlePageAuthor
            case "credit":
                type = .titlePageCredit
            case "source":
                type = . titlePageSource
            case "draft date":
                type = .titlePageDraftDate
            case "contact":
                type = .titlePageContact
            default:
                type = .titlePageUnknown
        }
        
        var elementLines:[Line] = []
                
        for i in 0..<lines.count {
            let l = lines[i]
            l.type = type
            elementLines.append(l)
        }
                
        return elementLines
    }
    
    @objc public func stringFor(_ key:String) -> String {
        guard let lines = get(key) else { return "" }
        var string = ""
        
        for line in lines {
            string.append(line.stripFormatting())
            if lines.count > 0 && line != lines.last {
                string.append("\n")
            }
        }
        
        return string
    }
    
    @objc public var title:[Line] {
        return get("title") ?? []
    }
    
    @objc public var credit:[Line] {
        return get("credit") ?? []
    }
    
    @objc public var authors:[Line] {
        return get("authors") ?? []
    }
    
    @objc public var contact:[Line] {
        return get("contact") ?? []
    }
    
    @objc public var draftDate:[Line] {
        return get("draft date") ?? []
    }
    
    @objc public var notes:[Line] {
        return get("notes") ?? []
    }
}
