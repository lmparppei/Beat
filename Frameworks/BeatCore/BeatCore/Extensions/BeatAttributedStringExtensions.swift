//
//  BeatAttributedStringExtensions.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

public extension NSAttributedString {
	@objc func height(containerWidth: CGFloat) -> CGFloat {
		let rect = self.boundingRect(with: CGSize.init(width: containerWidth, height: CGFloat.greatestFiniteMagnitude),
									 options: [.usesLineFragmentOrigin, .usesFontLeading],
									 context: nil)
		return ceil(rect.size.height)
	}
	
	func width(containerHeight: CGFloat) -> CGFloat {
		let rect = self.boundingRect(with: CGSize.init(width: CGFloat.greatestFiniteMagnitude, height: containerHeight),
									 options: [.usesLineFragmentOrigin, .usesFontLeading],
									 context: nil)
		return ceil(rect.size.width)
	}
	/// Simply returns a range of the full string (`0...length`)
	var range:NSRange {
		get { return NSRange(location: 0, length: self.length) }
	}
	
	func uppercased() -> NSAttributedString {

		let result = NSMutableAttributedString(attributedString: self)

		result.enumerateAttributes(in: NSRange(location: 0, length: length), options: []) {_, range, _ in
			result.replaceCharacters(in: range, with: (string as NSString).substring(with: range).uppercased())
		}

		return result
	}
    
    @objc func trimmedAttributedString(set:CharacterSet) -> NSAttributedString {
        var str = self.copy() as! NSAttributedString
        
        while str.length > 0 {
            guard let chr = str.string[str.length - 1].unicodeScalars.first else { break }
            
            if set.contains(chr) {
                str = str.attributedSubstring(from: NSMakeRange(0, self.length - 1))
            } else {
                break
            }
        }
        
        return str
    }
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

