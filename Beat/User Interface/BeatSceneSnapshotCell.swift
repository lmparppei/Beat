//
//  BeatSceneSnapshotCell.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

@objc public class BeatSceneSnapshotCell:NSTableCellView {
	@objc weak var editorDelegate:BeatEditorDelegate?
	@objc weak var scene:OutlineScene?
	
	var timer:Timer?
	var popover:NSPopover?
	
	@IBInspectable var snapshotWidth = 400.0
	@IBInspectable var padding = 10.0
	@IBInspectable var delay = 1.2
	
	override public func awakeFromNib() {
		super.awakeFromNib()
		
		let area = NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self)
		self.addTrackingArea(area)
	}
	
	public override func updateTrackingAreas() {
		super.updateTrackingAreas()
		if let trackingArea = self.trackingAreas.first {
			self.removeTrackingArea(trackingArea)
		}
		
		self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self))
	}
	
	override public func mouseEntered(with event: NSEvent) {
		super.mouseEntered(with: event)
		
		timer?.invalidate()
		
		if BeatUserDefaults.shared().getBool(BeatSettingShowSnapshotsInOutline) {
			timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { [weak self] timer in
				self?.showScreenshot()
			})
		}
	}
	
	/// Shows a popover view of current scene
	func showScreenshot() {
		if let scene = self.scene, let delegate = self.editorDelegate, let _ = self.window {
			// Create an image and a popover
			guard let image = BeatSceneSnapshot.create(scene: scene, delegate: delegate) else { return }
			
			// Padding + max width
			let factor = snapshotWidth / image.size.width
			let size = CGSizeMake(snapshotWidth, image.size.height * factor)
			
			self.popover = NSPopover()
			self.popover?.contentViewController = NSViewController(nibName: nil, bundle: nil)
			self.popover?.contentViewController?.view = FlippedView(frame: NSMakeRect(0.0, 0.0, size.width + padding * 2, size.height + padding * 2))
			
			let imageView = NSImageView(image: image)
			imageView.frame = NSMakeRect(padding, padding, size.width, size.height)
			imageView.imageScaling = .scaleProportionallyDown
			
			self.popover?.contentViewController?.view.addSubview(imageView)
			self.popover?.behavior = .transient
			
			self.popover?.show(relativeTo: self.frame, of: self, preferredEdge: .minX)
		}
	}
	
	override public func mouseExited(with event: NSEvent) {
		// Invalidate timer and close popover if needed
		closePopover()
		
		super.mouseExited(with: event)
	}
	
	/// Closes popover and invalidates hover timer
	@objc public func closePopover() {
		timer?.invalidate()
		timer = nil
		
		popover?.close()
		popover = nil
	}
}

class BeatSceneSnapshot:NSObject {
	/// Creates an image of the given scene in text view
	class func create(scene:OutlineScene, delegate:BeatEditorDelegate, maxHeight:CGFloat = 400.0) -> NSImage? {
		guard let textView = delegate.getTextView(),
			  let layoutManager = delegate.getTextView().layoutManager else {
			print("No text view")
			return nil
		}
		
		var range = scene.range()
		if NSMaxRange(range) == textView.text.count && textView.text.count > 0 {
			// For some mysterious reason, NSLayoutManager gives us a wrong rect if the range reaches the last symbol in text view.
			// Let's subtract a single characer from length to avoid that, even if this might cause weirdness in some cases.
			range.length -= 1
		}
		
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
		rect.origin.x += textView.textContainerInset.width
		rect.origin.y += textView.textContainerInset.height
		
		if rect.size.height > maxHeight { rect.size.height = maxHeight }
		
		if let bitmap = textView.bitmapImageRepForCachingDisplay(in: rect) {
			bitmap.size = rect.size
			textView.cacheDisplay(in: rect, to: bitmap)
			
			let image = NSImage(size: rect.size)
			image.addRepresentation(bitmap)
			return image
		} else {
			return nil
		}
	}
}
