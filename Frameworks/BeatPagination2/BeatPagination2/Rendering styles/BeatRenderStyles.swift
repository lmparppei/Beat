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
	@objc static public let shared = BeatRenderStyles()
	@objc static public let editor = BeatRenderStyles(stylesheet: "EditorStyles")
    public var styles:[String:RenderStyle] = [:]
	
	weak var delegate:BeatRenderStyleDelegate?
	var settings:BeatExportSettings?
	
    public init(stylesheet:String, delegate:BeatRenderStyleDelegate? = nil, settings:BeatExportSettings? = nil) {
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
	
    public func loadStyles(stylesheet:String = "Styles", additionalStyles:String = "") {
		let bundle = Bundle(for: type(of: self))
		let url = bundle.url(forResource: stylesheet, withExtension: "beatCSS")
		
		do {
			var stylesheet = try String(contentsOf: url!)
			stylesheet.append("\n\n" + additionalStyles)
			
			let parser = CssParser()
			let settings = (self.delegate != nil) ? self.delegate!.settings : self.settings
			
			styles = parser.parse(fileContent: stylesheet, settings: settings)
		} catch {
			os_log("BeatRenderStyles - WARNING: Loading stylesheet failed")
		}
	}
	
	@objc public func reload() {
		self.loadStyles()
	}
	
	@objc public func page() -> RenderStyle {
		guard let pageStyle = styles["page"] else {
			os_log("BeatRenderStyles - WARNING: No page style defined in stylesheet")
			return RenderStyle(rules: [:])
		}
		return pageStyle
	}
	
	@objc public func forElement(_ name:String) -> RenderStyle {
		return styles[name] ?? RenderStyle(rules: ["width-a4": self.page().defaultWidthA4, "width-us": self.page().defaultWidthLetter])
	}
}

// MARK: - Render style

@objc public class RenderStyle:NSObject {
	@objc public var bold:Bool = false
	@objc public var italic:Bool = false
	@objc public var underline:Bool = false
	@objc public var uppercase:Bool = false
	
	@objc public var textAlign:String = "left"
	
	@objc public var marginTop:CGFloat = 0
	@objc public var marginLeft:CGFloat = 0
	@objc public var marginBottom:CGFloat = 0
	@objc public var marginRight:CGFloat = 0
	@objc public var paddingLeft:CGFloat = 0
	@objc public var contentPadding:CGFloat = 0

	@objc public var lineHeight:CGFloat = 0
	
	@objc public var widthA4:CGFloat = 0
	@objc public var widthLetter:CGFloat = 0
	
	@objc public var defaultWidthA4:CGFloat = 0
	@objc public var defaultWidthLetter:CGFloat = 0
	
    public init(rules:[String:Any]) {
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
	
    public func styleNameToProperty (name:String) -> String {
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
	
	override public class func setValue(_ value: Any?, forUndefinedKey key: String) {
		print("RenderStyle: Unknown key: ", key)
	}
}
