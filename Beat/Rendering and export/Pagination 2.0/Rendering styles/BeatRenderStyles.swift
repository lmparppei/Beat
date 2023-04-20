//
//  RenderStyle.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 31.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

// MARK: Initialization and stylesheet loading

@objc protocol BeatRenderStyleDelegate {
	var settings:BeatExportSettings { get }
}

@objc class BeatRenderStyles:NSObject {
	@objc static let shared = BeatRenderStyles()
	@objc static let editor = BeatRenderStyles(stylesheet: "EditorStyles")
	var styles:[String:RenderStyle] = [:]
	
	weak var delegate:BeatRenderStyleDelegate?
	var settings:BeatExportSettings?
	
	init(stylesheet:String, delegate:BeatRenderStyleDelegate? = nil, settings:BeatExportSettings? = nil) {
		self.delegate = delegate
		self.settings = settings
		
		super.init()
		loadStyles(stylesheet: stylesheet)
	}
	
	override private init() {
		super.init()
		loadStyles()
	}
	
	private init(stylesheet:String) {
		super.init()
		loadStyles(stylesheet: stylesheet)
	}
	
	func loadStyles(stylesheet:String = "Styles", additionalStyles:String = "") {
		let url = Bundle.main.url(forResource: stylesheet, withExtension: "beatCSS")
		do {
			var stylesheet = try String(contentsOf: url!)
			stylesheet.append("\n\n" + additionalStyles)
			
			let parser = CssParser()
			let settings = (self.delegate != nil) ? self.delegate!.settings : self.settings
			
			styles = parser.parse(fileContent: stylesheet, settings: settings)
		} catch {
			print("Loading stylesheet failed")
		}
	}
	
	@objc func reload() {
		self.loadStyles()
	}
	
	@objc func page() -> RenderStyle {
		return styles["page"]!
	}
	
	@objc func forElement(_ name:String) -> RenderStyle {
		return styles[name] ?? RenderStyle(rules: ["width-a4": self.page().defaultWidthA4, "width-us": self.page().defaultWidthLetter])
	}
}

// MARK: - Render style

class RenderStyle:NSObject {
	@objc var bold:Bool = false
	@objc var italic:Bool = false
	@objc var underline:Bool = false
	@objc var uppercase:Bool = false
	
	@objc var textAlign:String = "left"
	
	@objc var marginTop:CGFloat = 0
	@objc var marginLeft:CGFloat = 0
	@objc var marginBottom:CGFloat = 0
	@objc var marginRight:CGFloat = 0
	@objc var paddingLeft:CGFloat = 0
	@objc var contentPadding:CGFloat = 0

	@objc var lineHeight:CGFloat = 0
	
	@objc var widthA4:CGFloat = 0
	@objc var widthLetter:CGFloat = 0
	
	@objc var defaultWidthA4:CGFloat = 0
	@objc var defaultWidthLetter:CGFloat = 0
	
	init(rules:[String:Any]) {
		super.init()

		for key in rules.keys {
			// Create property name based on the rule key
			let value = rules[key]!
			let property = styleNameToProperty(name: key)
			
			// Check that the property exists to avoid any unnecessary crashes
			if (self.responds(to: Selector(property))) {
				self.setValue(value, forKey: property)
			} else {
				print("Warning: Unrecognized BeatCSS key: ", property)
			}
		}
	}
	
	func styleNameToProperty (name:String) -> String {
		switch name.lowercased() {
		case "width-a4":
			return "widthA4"
		case "width-us":
			return "widthLetter"
		case "text-align":
			return "textAlign"
		case "margin-top":
			return "marginTop"
		case "margin-bottom":
			return "marginBottom"
		case "margin-left":
			return "marginLeft"
		case "margin-right":
			return "marginRight"
		case "padding-left":
			return "paddingLeft"
		case "line-height":
			return "lineHeight"
		case "default-width-a4":
			return "defaultWidthA4"
		case "default-width-us":
			return "defaultWidthLetter"
		case "content-padding":
			return "contentPadding"
		default:
			return name
		}
	}
	
	override class func setValue(_ value: Any?, forUndefinedKey key: String) {
		print("RenderStyle: Unknown key: ", key)
	}
}
