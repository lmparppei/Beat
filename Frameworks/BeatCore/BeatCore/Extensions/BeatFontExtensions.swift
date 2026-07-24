//
//  BeatFontExtensions.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//


#if os(iOS)
import UIKit
public typealias BFont = UIFont
public typealias BFontDescriptor = UIFontDescriptor
#else
import Foundation
public typealias BFont = NSFont
public typealias BFontDescriptor = NSFontDescriptor

extension BFontDescriptor.SymbolicTraits {
	static var italicTrait: BFontDescriptor.SymbolicTraits {
#if os(iOS)
		return .traitItalic
#else
		return .italic
#endif
	}
	
	static var boldTrait:BFontDescriptor.SymbolicTraits {
#if os(iOS)
		return .traitBold
#else
		return .bold
#endif
	}
}

#endif

@objc public extension BFont {

	/// Creates a new font descriptor with the given traits. macOS and iOS have differing optional types, hence this mess.
	@objc func withTraits(_ traits: BFontDescriptor.SymbolicTraits) -> BFont {
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
	
	@objc func withAddedTraits(_ traits: BFontDescriptor.SymbolicTraits) -> BFont {
		let descriptor = fontDescriptor.withSymbolicTraits(
			fontDescriptor.symbolicTraits.union(traits)
		)
		return BFont(descriptor: descriptor, size: pointSize) ?? self
	}

	/// Returns the font with italic variant
	@objc func italics() -> BFont {
		return withTraits(.italicTrait)
	}
	
	/// This method ADDS italic trait to the font, and won't override the old ones
	@objc func italicized() -> BFont {
		return withAddedTraits(.italicTrait)
	}

	/// Returns the font with bold variant
	@objc func bold() -> BFont {
		return withTraits(.boldTrait)
	}
	
	/// This method ADDS bolded trait to the font, and won't override the old ones
	@objc func bolded() -> BFont {
		return withAddedTraits(.boldTrait)
	}

	/// Returns the font with bold+italic variant
	@objc func boldItalics() -> BFont {
		return withTraits([ .boldTrait, .italicTrait ])
	}
	
	@objc func font(size:CGFloat, traits:BFontDescriptor.SymbolicTraits) -> BFont? {
		return BFont(name: self.fontName, size: size)?.withTraits(traits)
	}
}

