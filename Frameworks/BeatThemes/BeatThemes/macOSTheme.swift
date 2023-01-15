//
//  macOSTheme.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatDynamicColor

@objc public class macOSTheme: NSObject, BeatTheme, NSCopying {
	public var backgroundColor: DynamicColor!
    public var selectionColor: DynamicColor!
    public var textColor: DynamicColor!
    public var invisibleTextColor: DynamicColor!
    public var caretColor: DynamicColor!
    public var commentColor: DynamicColor!
    public var marginColor: DynamicColor!
    public var outlineBackground: DynamicColor!
    public var outlineHighlight: DynamicColor!
    public var sectionTextColor: DynamicColor!
    public var synopsisTextColor: DynamicColor!
    public var pageNumberColor: DynamicColor!
    public var highlightColor: DynamicColor!
	
    public var genderWomanColor: DynamicColor!
    public var genderManColor: DynamicColor!
    public var genderOtherColor: DynamicColor!
    public var genderUnspecifiedColor: DynamicColor!
	
	
	var propertyToValue:Dictionary<String, String>?
	var name:String? = ""
	
	override public init() {
		super.init()
		
		propertyToValue = [
			"backgroundColor": "Background",
			"marginColor": "Margin",
			"selectionColor": "Selection",
			"textColor": "Text",
			"commentColor": "Comment",
			"invisibleTextColor": "InvisibleText",
			"caretColor": "Caret",
			"pageNumberColor": "PageNumber",
			"synopsisTextColor": "SynopsisText",
			"sectionTextColor": "SectionText",
			"outlineBackground": "OutlineBackground",
			"outlineHighlight": "OutlineHighlight",
			"highlightColor": "Highlight",
			"genderWomanColor": "Woman",
			"genderManColor": "Man",
			"genderOtherColor": "Other",
			"genderUnspecifiedColor": "Unspecified"
		]
	}
	
	public func themeAsDictionary(withName name: String!) -> [AnyHashable : Any]! {
		var themeName = name
		if (themeName == "") {
			themeName = self.name
		}
		
		let light = NSMutableDictionary()
		let dark = NSMutableDictionary()
		
		for property:String in propertyToValue!.keys {
			// Skip empty values (highlight can be one)
			if (self.value(forKey: property) == nil) { continue }
			
			let color:DynamicColor = self.value(forKey: property) as! DynamicColor
			let key = propertyToValue![property]!
			light[key] = color.valuesAsRGB()[0]
			dark[key] = color.valuesAsRGB()[1]
		}
		
		let result:Dictionary<AnyHashable, Any> = [
			"Name": themeName ?? "",
			"Light": light,
			"Dark": dark
		]
				
		return result
	}
	
	override public func copy() -> Any {
		let theme = macOSTheme()

		for key:String in self.propertyToValue!.keys {
			let color:DynamicColor = self.value(forKey: key) as! DynamicColor
			theme.setValue(color.copy(), forKey: key)
		}
		
		return theme
	}
	
	public func copy(with zone: NSZone? = nil) -> Any {
		let theme = macOSTheme()

		for key:String in self.propertyToValue!.keys {
			let color:DynamicColor = self.value(forKey: key) as! DynamicColor
			theme.setValue(color.copy(), forKey: key)
		}
		
		return theme
	}
}
