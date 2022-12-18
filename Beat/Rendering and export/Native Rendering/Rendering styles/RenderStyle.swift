//
//  RenderStyle.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 31.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

// MARK: Stylesheet

class Styles:NSObject {
	@objc static let shared = Styles()
	var styles:[String:RenderStyle] = [:]
	
	override init() {
		super.init()
		reloadStyles()
	}
	
	func reloadStyles() {
		let url = Bundle.main.url(forResource: "Styles", withExtension: "beatCSS")
		do {
			let stylesheet = try String(contentsOf: url!)
			let parser = CssParser()
			styles = parser.parse(fileContent: stylesheet)
		} catch {
			print("Loading stylesheet failed")
		}
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
