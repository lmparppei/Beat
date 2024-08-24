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
		// Creates a new font descriptor with the given traits.
		// macOS and iOS have differing optional types, hence this mess.
		
		#if os(iOS)
			guard let fd = self.fontDescriptor.withSymbolicTraits(traits)
			else { return self }
			
			let font = BFont(descriptor: fd, size: pointSize)
			return font
		#else
			let fd = self.fontDescriptor.withSymbolicTraits(traits)
			
			guard let font = BFont(descriptor: fd, size: pointSize)
			else { return self }
			 
			return font
		#endif
	}

	@objc func italics() -> BFont {
		#if os(iOS)
			return withTraits(.traitItalic)
		#else
			return withTraits(.italic)
		#endif
	}

	@objc func bold() -> BFont {
		#if os(iOS)
			return withTraits(.traitBold)
		#else
			return withTraits(.bold)
		#endif
	}

	@objc func boldItalics() -> BFont {
		#if os(iOS)
			return withTraits([ .traitBold, .traitItalic ])
		#else
			return withTraits([ .bold, .italic ])
		#endif
	}
}

