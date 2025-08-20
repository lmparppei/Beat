//
//  BeatStyle.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//

import Foundation
import BeatParsing
import OSLog

@objc public class BeatStylesheet:NSObject, BeatExportStyleProvider {
    @objc public var name = ""
    public var styles:[String:RenderStyle] = [:]
    public var editorStyles:[String:RenderStyle] = [:]
    //public var settings:BeatExportSettings?
    public weak var documentSettings:BeatDocumentSettings?
    
    var stylesheet:String?
    
    public init(url:URL, name:String, documentSettings:BeatDocumentSettings? = nil) {
        self.documentSettings = documentSettings
        self.name = name

        super.init()
        
        do {
            self.stylesheet = try String(contentsOf: url)
        } catch {
            print("Error loading editor stylesheet")
        }
        
        loadStyles()
    }
        
    /// Parses the style string
    public func loadStyles(additionalStyles:String = "") {
        // Parse render styles
        if self.stylesheet != nil {
            var stylesheet = String(stringLiteral: self.stylesheet!)
            stylesheet.append("\n\n" + additionalStyles)

            styles = CssParser().parse(fileContent: stylesheet, documentSettings: self.documentSettings)
        }        
    }
    
    /// Reloads the given style
    @objc public func reload(documentSettings:BeatDocumentSettings? = nil) {
        if (documentSettings != nil) { self.documentSettings = documentSettings }
        self.loadStyles()
    }
    
    @objc public func page() -> RenderStyle {
        guard let pageStyle = styles["page"] else {
            os_log("WARNING: No page style defined in stylesheet")
            return RenderStyle(rules: [:])
        }
        return pageStyle
    }
    
    /// Returns styles for given element type
    @objc public func forElement(_ name:String) -> RenderStyle {
        return styles[name] ?? RenderStyle(rules: ["width-a4": self.page().defaultWidthA4, "width-us": self.page().defaultWidthLetter])
    }
    
    /// Returns styles for given line, can be dynamic
    @objc public func forLine(_ line:Line) -> RenderStyle {
        let style = forElement(line.typeName())
        
        if style.hasConditionalStyles(), let dynamicStyle = style.dynamicStyles(for: line) {
            style.dynamicStyle = true
            return dynamicStyle
        }
        
        return style
    }
    
    /// Returns `true` if the style sheet has variable font sizes
    @objc public func variableFont() -> Bool {
        let page = page()
        return (page.fontType == .variableSansSerif || page.fontType == .variableSerif)
    }
    
    // MARK: style provider interface
    public func shouldPrintSections() -> Bool { return self.document._visibleElements.contains(.section) }
    public func shouldPrintSynopses() -> Bool { return self.document._visibleElements.contains(.synopse) }
    @objc public func overrideParagraphPaginationMode() -> Bool { return self.document.overrideParagraphPaginationMode }
}


// MARK: Shorthands for the styles
@objc extension BeatStylesheet {
    @objc public var action:RenderStyle {
        return self.forElement(Line.typeName(.action))
    }
    @objc public var dialogue:RenderStyle {
        return self.forElement(Line.typeName(.dialogue))
    }
    @objc public var parenthetical:RenderStyle {
        return self.forElement(Line.typeName(.parenthetical))
    }
    @objc public var character:RenderStyle {
        return self.forElement(Line.typeName(.character))
    }
    @objc public var titlePageElement:RenderStyle {
        return self.forElement(Line.typeName(.titlePageTitle))
    }
    @objc public var dualDialogueCharacter:RenderStyle {
        return self.forElement(Line.typeName(.dualDialogueCharacter))
    }
    @objc public var dualDialogueParenthetical:RenderStyle {
        return self.forElement(Line.typeName(.dualDialogueParenthetical))
    }
    @objc public var dualDialogue:RenderStyle {
        return self.forElement(Line.typeName(.dualDialogue))
    }
    @objc public var transition:RenderStyle {
        return self.forElement(Line.typeName(.transitionLine))
    }
    @objc public var document:RenderStyle {
        return self.forElement("document")
    }
    @objc public var section:RenderStyle {
        return self.forElement(Line.typeName(.section))
    }
    @objc public var heading:RenderStyle {
        return self.forElement(Line.typeName(.heading))
    }
    @objc public var titlePage:RenderStyle {
        return self.forElement("titlePage")
    }
    @objc public var pagination:RenderStyle {
        return self.forElement("pagination")
    }

}


// MARK: - Pagination shorthands for ObjC interop

extension BeatStylesheet {
    @objc public func hasPaginationRules() -> Bool {
        return self.pagination.paginationRules.count > 0
    }
    
    /// Ask if this item should be included or not
    @objc public func shouldInclude(_ type:LineType, after prevType:LineType) -> Bool {
        for rule in self.pagination.paginationRules {
            if rule.rule == .skip,
               rule.precededBy == prevType,
                rule.followedBy == type {
                return false
            }
        }
            
        return true
    }
}
