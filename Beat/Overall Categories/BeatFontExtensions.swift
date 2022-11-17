//
//  BeatFontExtensions.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//


#if os(iOS)
import UIKit
typealias BFont = UIFont
typealias BFontDescriptor = UIFontDescriptor
#else
import Foundation
typealias BFont = NSFont
typealias BFontDescriptor = NSFontDescriptor
#endif

extension BFont {

	@objc func withTraits(_ traits: BFontDescriptor.SymbolicTraits) -> BFont {

		// create a new font descriptor with the given traits
		let fd = self.fontDescriptor.withSymbolicTraits(traits)
		
		// return a new font with the created font descriptor
		let font = BFont(descriptor: fd, size: pointSize)
		
		if (font == nil) { return self }
		else { return font! }
	}

	@objc func italics() -> BFont {
		return withTraits(.italic)
	}

	@objc func bold() -> BFont {
		return withTraits(.bold)
	}

	@objc func boldItalics() -> BFont {
		return withTraits([ .bold, .italic ])
	}
}

