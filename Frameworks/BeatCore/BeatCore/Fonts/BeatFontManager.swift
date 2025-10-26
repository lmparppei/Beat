//
//  BeatFontManager.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 4.11.2024.
//

import Foundation

/// Template for loading a `BeatFontSet`
private struct BeatFontSetTemplate {
    var name:String
    var regular:String
    /// Alternative name for the font. Because we can't use font traits on Mojave, we always need to have a fallback name for any font, which is usually the font file name.
    var regularAlternative:String?
    var bold:String
    var italic:String
    var boldItalic:String
    var section:String?
    var synopsis:String?
    var emojis:String?
}
/**
 This is a replacement for the old font system, which provides a little more flexible font loading without the weird singleton mess.
 */
@objc public class BeatFontManager:NSObject {
    @objc static public let shared = BeatFontManager()

    private var fonts:[CGFloat:[String:BeatFontSet]] = [:]
    
    private let fontTemplates:[String:BeatFontSetTemplate] = [
        "mono serif": BeatFontSetTemplate(name: "Courier Prime",
                                  regular: "Courier Prime",
                                  regularAlternative: "CourierPrime",
                                  bold: "CourierPrime-Bold",
                                  italic: "CourierPrime-Italic",
                                  boldItalic: "CourierPrime-BoldItalic"),
        
        "mono serif new": BeatFontSetTemplate(name: "Courier New",
                                        regular: "Courier New",
                                        regularAlternative: "CourierNew",
                                        bold: "Courier New Bold",
                                        italic: "Courier New Italic",
                                        boldItalic: "Courier New Bold Italic"),
        
        "mono sans serif": BeatFontSetTemplate(name: "Courier Prime Sans",
                                       regular: "Courier Prime Sans",
                                       regularAlternative: "CourierPrimeSans",
                                       bold: "CourierPrimeSans-Bold",
                                       italic: "CourierPrimeSans-Italic",
                                       boldItalic: "CourierPrimeSans-BoldItalic"),
        
        "variable serif": BeatFontSetTemplate(name: "Variable Serif",
                                     regular: "Times New Roman",
                                     bold: "Times New Roman Bold",
                                     italic: "Times New Roman Italic",
                                     boldItalic: "Times New Roman Bold Italic",
                                     section: "Times New Roman Bold Italic"),
        
        "variable sans serif": BeatFontSetTemplate(name: "Variable Sans Serif",
                                                   regular: "Helvetica",
                                                   bold: "Helvetica Bold",
                                                   italic: "Helvetica Oblique",
                                                   boldItalic: "Helvetica Bold Oblique",
                                                   section: "Helvetica Bold")
    ]
    
    let typeToTypeName:[BeatFontType:String] = [
        .fixed: "mono serif",
        .fixedNew: "mono serif new",
        .fixedSansSerif: "mono sans serif",
        .variableSerif: "variable serif",
        .variableSansSerif: "variable sans serif"
    ]
    
    override private init() {
        super.init()
    }
    
    @objc public class var characterWidth:CGFloat {
        return 7.25
    }
    
    @objc public class var defaultFontName:String { return "mono serif" }
    @objc public var defaultFonts:BeatFontSet {
        return self.fonts(type: BeatFontManager.defaultFontName)!
    }
    
    @objc public func fonts(for type:BeatFontType) -> BeatFontSet? {
        return self.fonts(type: typeToTypeName[type] ?? "")
    }
    
    @objc public func fonts(with type:BeatFontType, scale:CGFloat) -> BeatFontSet? {
        return self.fonts(type: typeToTypeName[type] ?? "", scale: scale)
    }
    
    /// Returns a font set, similar to the old `BeatFonts` object.
    @objc public func fonts(type:String, scale:CGFloat = 1.0) -> BeatFontSet? {
        guard let template = fontTemplates[type] else {
            print("⚠️ No font template found for ", type);
            return nil
        }
        
        if let font = fonts[scale]?[type] {
            return font
        }
        
        if fonts[scale] == nil { fonts[scale] = [:] }
    
        let regularName = (BXFont(name: template.regular, size: 12.0) != nil) ? template.regular : template.regularAlternative ?? ""
        
        // Let's create a font set from template
        let font = BeatFontSet.name(template.name,
                                 size: 12.0,
                                 scale: scale,
                                 regular: regularName,
                                 bold: template.bold,
                                 italic: template.italic,
                                 boldItalic: template.boldItalic,
                                 sectionFont: template.section,
                                 synopsisFont: template.synopsis)
    
        fonts[scale]?[type] = font
        return font
    }
}
