//
//  BeatLaunchScreenButton.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is a port of BeatLauncButton for the purposes of learning Swift.
 Nothing special to see here.
 
 */

import Cocoa


class BeatLaunchScreenButton: NSButtonCell {
	//@property (nonatomic) IBInspectable NSString *localizationId;
	private var subtitleString: String {
		let str:String = NSLocalizedString(self.localizationId, comment: "")
		
		if (str.count != 0) {
			return str
		} else {
			return self.subtitle
		}
	}
	@IBInspectable var localizationId: String!
	@IBInspectable var subtitle: String!
	
	override func awakeFromNib() {
		let button:NSButton! = self.controlView as? NSButton
		button?.wantsLayer = true
		button?.layer?.cornerRadius = 5.0
		
		let trackingArea:NSTrackingArea = NSTrackingArea(rect: button.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
		button.addTrackingArea(trackingArea)
	}

	override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
		let button:NSButton! = self.controlView as? NSButton
		
		var appearance:NSAppearance? = nil
		
		if #available(macOS 11.0, *) {
			_ = NSAppearance.performAsCurrentDrawingAppearance(self.controlView!.window!.effectiveAppearance)
		} else {
			appearance = NSAppearance.current
			NSAppearance.current = self.controlView!.window!.effectiveAppearance
		}
		
		var color = NSColor.controlTextColor.withAlphaComponent(0.6)
		var topColor = NSColor.controlTextColor.withAlphaComponent(0.9)
		
		if button.isHighlighted {
			color = color.withAlphaComponent(1.0)
			topColor = NSColor.controlTextColor.withAlphaComponent(1.0)
		}
		
		let topTitle:String = button.title
		let bottomTitle:String = self.subtitleString
		
		let attrStr = NSMutableAttributedString(string: String(format: "%@\n%@", topTitle, bottomTitle))
		
		attrStr.addAttribute(NSAttributedString.Key.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: NSMakeRange(0, attrStr.string.count))
		attrStr.addAttribute(NSAttributedString.Key.foregroundColor, value:color, range: NSMakeRange(0, attrStr.string.count))
		attrStr.addAttribute(NSAttributedString.Key.foregroundColor, value:topColor, range: NSMakeRange(0, topTitle.count))

		attrStr.addAttribute(NSAttributedString.Key.font, value:NSFont.systemFont(ofSize: 13.0), range: NSMakeRange(0, topTitle.count))
		attrStr.addAttribute(NSAttributedString.Key.font, value:NSFont.systemFont(ofSize: 8.5), range: NSMakeRange(topTitle.count + 1, bottomTitle.count))
		
		
		
		let stringRect = NSMakeRect(controlView.frame.size.height + 8, (controlView.frame.size.height - attrStr.size().height) / 2 - 1,
									attrStr.size().width, attrStr.size().height )
		attrStr.draw(in: stringRect)
		
		// Restore appearance in older systems
		if #available(macOS 11.0, *) {
			// Do nothing
		} else {
			NSAppearance.current = appearance
		}
		
		return stringRect
	}
	
	override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
		let button:NSButton = controlView as! NSButton
		
		var appearance:NSAppearance? = nil
		if #available(macOS 11.0, *) {
			_ = NSAppearance.performAsCurrentDrawingAppearance(self.controlView!.window!.effectiveAppearance)
		} else {
			appearance = NSAppearance.current
			NSAppearance.current = self.controlView!.window!.effectiveAppearance
		}
		
		let scaledImage:NSImage = proporionalScaling(image, withSize: NSMakeSize(controlView.frame.size.height - 2.0 * 2, controlView.frame.size.height - 2.0 * 2))
		
		var color:NSColor = NSColor.controlTextColor.withAlphaComponent(0.6)
		if (button.isHighlighted) {
			color = color.withAlphaComponent(1.0)
		}
		
		scaledImage.lockFocus()
		color.set()

		let imageRect:NSRect = NSMakeRect(0, 0, scaledImage.size.width, scaledImage.size.height)
		imageRect.fill(using: NSCompositingOperation.sourceAtop)
		scaledImage.unlockFocus()
		
		let iRect = NSMakeRect(0 + 2, 0 + 2, scaledImage.size.width, scaledImage.size.height)
		scaledImage.draw(in: iRect)
		
		
		if #available(macOS 11.0, *) {
			// Do nothing
		} else {
			NSAppearance.current = appearance
		}
	}
	

	func proporionalScaling(_ image: NSImage, withSize targetSize: NSSize) -> NSImage {
		let sourceImage:NSImage = image
		let newImage:NSImage = NSImage.init(size: targetSize)
		
		if sourceImage.isValid {
			let imageSize = sourceImage.size
			let width:CGFloat = imageSize.width
			let height:CGFloat = imageSize.height
			
			let targetWidth:CGFloat = targetSize.width
			let targetHeight:CGFloat = targetSize.height
			
			var scaleFactor:CGFloat = 0.0
			var scaleWidth = targetWidth
			var scaleHeight = targetHeight
			
			var thumbnailPoint:NSPoint = NSPoint.zero
			
			if !NSEqualSizes(imageSize, targetSize) {
				let widthFactor:CGFloat = targetWidth / width
				let heightFactor:CGFloat = targetHeight / height
				
				if (widthFactor < heightFactor) {
					scaleFactor = widthFactor
				} else {
					scaleFactor = heightFactor
				}
				
				scaleWidth = width * scaleFactor
				scaleHeight = height * heightFactor
				
				if (widthFactor < heightFactor) {
					thumbnailPoint.y = (targetHeight - scaleWidth) * 0.5
				}
				else if (widthFactor > heightFactor) {
					thumbnailPoint.x = (targetWidth - scaleWidth) * 0.5
				}
			}
			
			newImage.lockFocus()
			
			var thumbnailRect:NSRect = NSZeroRect
			thumbnailRect.origin = thumbnailPoint
			thumbnailRect.size.width = scaleWidth
			thumbnailRect.size.height = scaleHeight
			
			sourceImage.draw(in: thumbnailRect, from: NSRect.zero, operation: NSCompositingOperation.sourceOver, fraction: 1.0)
			newImage.unlockFocus()
		}
		
		return newImage
	}
	
	override func mouseEntered(with event: NSEvent) {
		var appearance:NSAppearance? = nil
		if #available(macOS 11.0, *) {
			_ = NSAppearance.performAsCurrentDrawingAppearance(self.controlView!.window!.effectiveAppearance)
		} else {
			appearance = NSAppearance.current
			NSAppearance.current = self.controlView!.window!.effectiveAppearance
		}
		
		self.controlView?.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
		
		if #available(macOS 11.0, *) {
			// Do nothing
		} else {
			NSAppearance.current = appearance
		}
	}
	override func mouseExited(with event: NSEvent) {
		var appearance:NSAppearance? = nil
		if #available(macOS 11.0, *) {
			_ = NSAppearance.performAsCurrentDrawingAppearance(self.controlView!.window!.effectiveAppearance)
		} else {
			appearance = NSAppearance.current
			NSAppearance.current = self.controlView!.window!.effectiveAppearance
		}
		
		self.controlView?.layer?.backgroundColor = NSColor.clear.cgColor
		
		if #available(macOS 11.0, *) {
			// Do nothing
		} else {
			NSAppearance.current = appearance
		}
	}
}

/*
 
 I'm pointing and describing
 you can be my guide
 the skin is just a road map
 the view is very nice
 
 Imagine looking at a picture
 imagine driving in a car
 imagine rolling down the window
 imagine opening the door
 
 */
