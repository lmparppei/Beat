//
//  BeatTheme.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import BeatDynamicColor

@objc protocol BeatTheme: NSObjectProtocol, NSCopying {
	var backgroundColor: DynamicColor! { get set }
	var selectionColor: DynamicColor!  { get set }
	var textColor: DynamicColor!  { get set }
	var invisibleTextColor: DynamicColor!  { get set }
	var caretColor: DynamicColor!  { get set }
	var commentColor: DynamicColor!  { get set }
	var marginColor: DynamicColor!  { get set }
	var outlineBackground: DynamicColor!  { get set }
	var outlineHighlight: DynamicColor!  { get set }
	var sectionTextColor: DynamicColor!  { get set }
	var synopsisTextColor: DynamicColor!  { get set }
	var pageNumberColor: DynamicColor!  { get set }
	var highlightColor: DynamicColor!  { get set }
	
	var genderWomanColor: DynamicColor!  { get set }
	var genderManColor: DynamicColor!  { get set }
	var genderOtherColor: DynamicColor!  { get set }
	var genderUnspecifiedColor: DynamicColor!  { get set }
	
	var propertyToValue:Dictionary<String, String>?  { get set }
	var name:String? { get set }

	func themeAsDictionary(withName name: String!) -> [AnyHashable : Any]!
	
}

@objc class Test:NSObject {
    func test() {
        print("test")
    }
}
