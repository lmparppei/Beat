//
//  BeatAttributedStringExtensions.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import UXKit

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


@objc public enum AttributedBlockType: Int {
    case text
    case symbol
}

@objc public class AttributedBlock: NSObject {
    let type: AttributedBlockType
    let value: Any

    @objc public init(type: AttributedBlockType, value: Any) {
        self.type = type
        self.value = value
    }
}

@objc public extension NSAttributedString {
    // Thank you, nayooti on stackoverflow
    @objc static func create(
        blocks: [AttributedBlock],
        font: UXFont,
        textColor: UXColor,
        symbolColor: UXColor,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        
        let actualFont = font
        let actualTextColor = textColor
        let actualSymbolColor = symbolColor
        
        let attributedBlocks: [NSAttributedString] = blocks.compactMap { block in
            if block.type == .text, let text = block.value as? String {
                return NSAttributedString(
                    string: text,
                    attributes: [
                        NSAttributedString.Key.font: actualFont,
                        NSAttributedString.Key.foregroundColor: actualTextColor
                    ]
                )
            } else if block.type == .symbol, let imageName = block.value as? String {
                let attachment = NSTextAttachment()
            #if os(macOS)
                if #available(macOS 12.0, *) {
                    var config = NSImage.SymbolConfiguration(pointSize: actualFont.pointSize, weight: .regular)
                    config = config.applying(.init(hierarchicalColor: actualTextColor))
                    if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Marker")?.withSymbolConfiguration(config)?.tinting(with: actualTextColor) {
                        // Create a template image
                        attachment.image = image.rotated(by: -90.0)
                    }
                    
                }
            #else
                if let image = UIImage(systemName: imageName) {
                    attachment.image = image.withConfiguration(UIImage.SymbolConfiguration(pointSize: actualFont.pointSize, weight: .regular)).withTintColor(actualSymbolColor)
                }
            #endif
                
                if let image = attachment.image {
                    attachment.bounds = CGRect(x: 0, y: (actualFont.capHeight - image.size.height).rounded() / 2 - 1.0, width: image.size.width, height: image.size.height)
                }

                return NSAttributedString(attachment: attachment)
            } else {
                return nil
            }
        }
        
        let string = NSMutableAttributedString(string: "")
        attributedBlocks.forEach {
            string.append($0)
        }
        
        string.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: string.range)
        
        return string
    }
}

#if os(macOS)

extension NSImage {
    func tinting(with tintColor: NSColor) -> NSImage {
        if #available(macOS 12.0, *) {
            let symbolConfiguration = self.symbolConfiguration
            
            var tintedSymbolImage = self.copy() as! NSImage
            tintedSymbolImage.lockFocus()
            
            // Apply the tint color
            tintColor.set()
            NSRect(origin: .zero, size: self.size).fill(using: .sourceAtop)
            
            tintedSymbolImage.unlockFocus()
            
            tintedSymbolImage.isTemplate = true
            tintedSymbolImage = tintedSymbolImage.withSymbolConfiguration(symbolConfiguration)!
            
            return tintedSymbolImage
        } else {
            return self
        }
    }
    func rotated(by degrees : CGFloat) -> NSImage {
        var imageBounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let rotatedSize = AffineTransform(rotationByDegrees: degrees).transform(size)
        let newSize = CGSize(width: abs(rotatedSize.width), height: abs(rotatedSize.height))
        let rotatedImage = NSImage(size: newSize)

        imageBounds.origin = CGPoint(x: newSize.width / 2 - imageBounds.width / 2, y: newSize.height / 2 - imageBounds.height / 2)

        let otherTransform = NSAffineTransform()
        otherTransform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        otherTransform.rotate(byDegrees: degrees)
        otherTransform.translateX(by: -newSize.width / 2, yBy: -newSize.height / 2)

        rotatedImage.lockFocus()
        otherTransform.concat()
        draw(in: imageBounds, from: CGRect.zero, operation: NSCompositingOperation.copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
}
#endif
