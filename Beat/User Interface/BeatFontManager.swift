//
//  BeatFontManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Generic font manager. Unused for now.
 
 */

#if os(iOS)
import UIKit
public typealias BeatFont = UIFont
#else
import AppKit
public typealias BeatFont = NSFont
#endif

struct BeatFontFace {
	var regular:BeatFont!
	var bold:BeatFont!
	var italic:BeatFont!
	var boldItalic:BeatFont!
	var italicCourier:BeatFont!
}

class BeatFontManager:NSObject {
	@objc var courier = BeatFont(name: "Courier Prime", size: 12.0)
	@objc var boldCourier = BeatFont(name: "Courier Prime Bold", size: 12.0)
	@objc var boldItalicCourier = BeatFont(name: "Courier Prime Bold Italic", size: 12.0)
	@objc var italicCourier = BeatFont(name: "Courier Prime Italic", size: 12.0)

	var serif:BeatFontFace
	var sansSerif:BeatFontFace
	
	private static var sharedFontManager: BeatFontManager = {
		return BeatFontManager(fontSize: 12.0)
	}()
	
	private init(fontSize size:CGFloat) {
		serif = BeatFontFace(
			regular: BeatFont(name: "Courier Prime", size: size),
			bold: BeatFont(name: "Courier Prime Bold", size: size),
			italic: BeatFont(name: "Courier Prime Italic", size: size),
			boldItalic: BeatFont(name: "Courier Prime Bold Italic", size: size),
			italicCourier: BeatFont(name: "Courier Prime Italic", size: size)
			)
		
		sansSerif = BeatFontFace(
			regular: BeatFont(name: "Courier Prime Sans", size: size),
			bold: BeatFont(name: "Courier Prime Sans Bold", size: size),
			italic: BeatFont(name: "Courier Prime Sans Italic", size: size),
			boldItalic: BeatFont(name: "Courier Prime Sans Bold Italic", size: size),
			italicCourier: BeatFont(name: "Courier Prime Sans Italic", size: size)
			)
		
		super.init()
	}

	class func shared() -> BeatFontManager {
		return sharedFontManager
	}
	}
