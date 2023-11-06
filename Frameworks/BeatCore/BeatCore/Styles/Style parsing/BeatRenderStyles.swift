//
//  RenderStyle.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 31.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import OSLog

// MARK: Initialization and stylesheet loading

@objc public protocol BeatRenderStyleDelegate {
	var settings:BeatExportSettings { get }
}

@objc public class BeatRenderStyles:NSObject {
    /*
	@objc static public let shared = BeatRenderStyles()
	@objc static public let editor = BeatRenderStyles(stylesheet: "Screenplay-editor")
    */
    
    public var styles:[String:RenderStyle] = [:]
    public var editorStyles:[String:RenderStyle] = [:]
	
    
	weak var delegate:BeatRenderStyleDelegate?
	var settings:BeatExportSettings?
    
    var renderStylesheet:String?
    var editorStylesheet:String?
	
    public init(url:URL, delegate:BeatRenderStyleDelegate? = nil, settings:BeatExportSettings? = nil) {
		self.delegate = delegate
		self.settings = settings
        		
		super.init()
        
        let editorStyleURL = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: ".beatCSS", with: "-editor.beatCSS"))

        // Load renderer stylesheet
        do {
            self.renderStylesheet = try String(contentsOf: url)
            self.editorStylesheet = try String(contentsOf: editorStyleURL)
        } catch {
            print("Error loading editor stylesheet")
        }
        
		loadStyles()
	}
        
	/// Parses the style string
    public func loadStyles(additionalStyles:String = "") {
        let settings = (self.delegate != nil) ? self.delegate!.settings : self.settings
        let parser = CssParser()
        
        // Parse render styles
        if self.renderStylesheet != nil {
            var stylesheet = String(stringLiteral: self.renderStylesheet ?? "")
            stylesheet.append("\n\n" + additionalStyles)
            
            styles = parser.parse(fileContent: stylesheet, settings: settings)
        }
        
        // Parse editor styles
        if self.editorStylesheet != nil {
            var stylesheet = String(stringLiteral: self.editorStylesheet ?? "")
            stylesheet.append("\n\n" + additionalStyles)
            
            styles = parser.parse(fileContent: stylesheet, settings: settings)
        }
	}
	
    /// Reloads the given style
	@objc public func reload() {
		self.loadStyles()
	}
    
    @objc public func page() -> RenderStyle {
		guard let pageStyle = styles["page"] else {
			os_log("WARNING: No page style defined in stylesheet")
			return RenderStyle(rules: [:])
		}
		return pageStyle
	}
	
	@objc public func forElement(_ name:String) -> RenderStyle {
		return styles[name] ?? RenderStyle(rules: ["width-a4": self.page().defaultWidthA4, "width-us": self.page().defaultWidthLetter])
	}
}

// MARK: Shorthands for the styles
@objc extension BeatRenderStyles {
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
}
