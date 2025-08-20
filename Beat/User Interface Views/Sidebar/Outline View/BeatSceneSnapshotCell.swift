//
//  BeatSceneSnapshotCell.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc public class BeatSceneSnapshotCell:NSTableCellView, NSStackViewDelegate {
	@objc weak var editorDelegate:BeatEditorDelegate?
	@objc weak var scene:OutlineScene?
	@objc weak var outlineView:BeatOutlineView?
	
	//let stackView = BeatOutlineStackView()
	@IBOutlet weak var stackView:BeatOutlineStackView?
	
	var timer:Timer?
	var popover:NSPopover?
			
	@IBInspectable var snapshotWidth = 400.0
	@IBInspectable var padding = 10.0
	@IBInspectable var delay = 1.2
	
	override public func awakeFromNib() {
		super.awakeFromNib()
		
		let area = NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self)
		self.addTrackingArea(area)
		
		textField?.translatesAutoresizingMaskIntoConstraints = false
	}
	
	@objc func configure(delegate:BeatEditorDelegate?, scene:OutlineScene?, outlineView:BeatOutlineView?) {
		let dark = (NSApplication.shared.delegate as? BeatAppDelegate)?.isDark() ?? false
		guard let scene, let stackView else { return }
				
		self.outlineView = outlineView
		self.editorDelegate = delegate
		self.scene = scene
		
		let provider = OutlineItemProvider(scene: scene, dark: dark)
		setupStackView()
		
		// Add scene heading
		textField?.attributedStringValue = provider.heading()
		
		// Add all items
		provider.items().forEach { item in
			let label = RoundedLabel(item: item, tableCell: self)
			stackView.addArrangedSubview(label)
			//stackView.addView(label, in: .leading)
			
			// Force full width
			label.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
		}
		if let lastLabel = stackView.arrangedSubviews.last, stackView.arrangedSubviews.count > 1 {
			// After layout
			DispatchQueue.main.async {
				lastLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
			}
		}
		
		self.layoutSubtreeIfNeeded()
	}
	
	public override var intrinsicContentSize: NSSize {
		if let stackView {
			return stackView.intrinsicContentSize
		} else {
			return super.intrinsicContentSize
		}
	}
	
	private func setupStackView() {
		guard let stackView else { return }
				
		let views = stackView.arrangedSubviews
		for view in views {
			if view != textField { stackView.removeView(view) }
		}
		
		stackView.superview?.layoutSubtreeIfNeeded()
				
		stackView.spacing = 4
		
		stackView.orientation = .vertical
		stackView.alignment = .leading
		stackView.distribution = .fill
		
		// Set up constraints
		stackView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			stackView.topAnchor.constraint(equalTo: topAnchor),
			stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
			stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
			stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
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
				// Make sure the mouse pointer is still in this cell
				guard let _self = self, let window = _self.window else { return }
				let mouseLoc = window.convertPoint(fromScreen: NSEvent.mouseLocation)
				let localLoc = _self.convert(mouseLoc, from: nil)
				
				if _self.bounds.contains(localLoc) {
					_self.showScreenshot()
				}
			})
		}
	}
	
	/// Shows a popover view of current scene
	func showScreenshot() {
		// First close all previous snapshots
		self.outlineView?.closeSnapshots()
		
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
		
		self.outlineView?.addSnapshot(self)
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
	
	var sceneMinimumHeight:CGFloat {
		if BeatUserDefaults.shared().getBool(BeatSettingRelativeOutlineHeights), let scene {
			
			let sizeModifier = BeatUserDefaults.shared().getFloat(BeatSettingOutlineFontSizeModifier) * 0.1 + 1
			let modifier = 80.0 * sizeModifier

			if let pages = self.outlineView?.editorDelegate.pagination().numberOfPages, pages > 0 {
				// Calculate the relative size of the scene
				let relativeHeight = modifier * scene.printedLength
				return relativeHeight
			}
		}
		
		return 0.0
	}
}

class BeatSceneSnapshot:NSObject {
	/// Creates an image of the given scene in text view
	class func create(scene:OutlineScene, delegate:BeatEditorDelegate, maxHeight:CGFloat = 400.0) -> NSImage? {
		guard let textView = delegate.getTextView(),
			  let layoutManager = delegate.getTextView().layoutManager else {
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

class RoundedLabel:NSTextField {
	var bgColor = NSColor.white.withAlphaComponent(0.05).cgColor
	var item:BeatOutlineItemData
	weak var tableCell:BeatSceneSnapshotCell?
	
	init(item:BeatOutlineItemData, tableCell:BeatSceneSnapshotCell) {
		self.item = item
		self.tableCell = tableCell
		super.init(frame: .zero)
		
		let area = NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self)
		self.addTrackingArea(area)
				
		attributedStringValue = item.text
		
		isEditable = false
		isSelectable = false
		isBordered = false
		drawsBackground = false
		
		lineBreakMode = .byWordWrapping
		usesSingleLineMode = false
		
		cell?.wraps = true
		cell?.isScrollable = false
		
		wantsLayer = true
		layer?.cornerRadius = 8  // Rounded edges
		layer?.masksToBounds = true
		
		font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
		textColor = .white
		
		translatesAutoresizingMaskIntoConstraints = false
		
		setContentHuggingPriority(.required, for: .vertical)
		setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var intrinsicContentSize: NSSize {
		let size = super.intrinsicContentSize
		return NSSize(width: size.width, height: size.height)
	}
	
	public override func updateTrackingAreas() {
		super.updateTrackingAreas()
		if let trackingArea = self.trackingAreas.first {
			self.removeTrackingArea(trackingArea)
		}
		
		self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self))
	}
	
	override func mouseEntered(with event: NSEvent) {
		self.layer?.backgroundColor = bgColor
	}
	override func mouseExited(with event: NSEvent) {
		self.layer?.backgroundColor = nil
	}
	
	override func mouseDown(with event: NSEvent) {
		var focus = false
		let editor = self.tableCell?.editorDelegate
		
		if let line = item.line {
			editor?.selectedRange = NSMakeRange(line.position, 0)
			editor?.scroll(to: line.range(), callback: {})
			focus = true
		} else if item.range.location != 0 && item.range.location != NSNotFound {
			editor?.selectedRange = item.range
			focus = true
		}
		
		if focus {
			editor?.focusEditor?()
		}
	}
}

class BeatOutlineItemContainerView:NSView {
	@IBOutlet weak var outlineCell:BeatSceneSnapshotCell?
}

class BeatOutlineStackView:NSStackView {
	@IBOutlet weak var outlineCell:BeatSceneSnapshotCell?
	
	override var fittingSize: NSSize {
		let size = super.fittingSize
		print("        stack fitting", size.height)
		return size
	}
	
	override var intrinsicContentSize: NSSize {
		var size = super.intrinsicContentSize
		
		if BeatUserDefaults.shared().getBool(BeatSettingRelativeOutlineHeights) {
			//self.layoutSubtreeIfNeeded()
			if let cell = outlineCell, let scene = cell.scene {
				let sizeModifier = BeatUserDefaults.shared().getFloat(BeatSettingOutlineFontSizeModifier) * 0.1 + 1
				let modifier = 90.0 * sizeModifier

				if let pages = cell.outlineView?.editorDelegate.pagination().numberOfPages, pages > 0 {
					// Calculate the relative size of the scene
					let relativeHeight = modifier * scene.printedLength
					
					if relativeHeight > size.height {
						size.height = relativeHeight
						print("size", size)
					}
					return size
				}
			}
		}
		
		return size
	}
}

extension NSView {
	var ancestorOutlineView: NSOutlineView? {
		var view: NSView? = self
		while let currentView = view {
			if let outlineView = currentView as? NSOutlineView {
				return outlineView
			}
			view = currentView.superview
		}
		return nil
	}
}

