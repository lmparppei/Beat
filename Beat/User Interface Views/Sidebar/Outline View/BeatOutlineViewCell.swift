//
//  BeatSceneSnapshotCell.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc public class BeatOutlineViewCell:NSTableCellView, NSStackViewDelegate {
	@objc weak var editorDelegate:BeatEditorDelegate?
	@objc weak var scene:OutlineScene?
	@objc weak var outlineView:BeatOutlineView?
	
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
		
		// Add scene heading. For sections, heading is always visible.
		if provider.options.contains(.includeHeading) || scene.type == .section {
			textField?.isHidden = false
			textField?.attributedStringValue = provider.heading()
 		} else {
			textField?.isHidden = true
			textField?.stringValue = ""
		}
		
		// Add all items
		provider.items().forEach { item in
			let label = RoundedLabel(item: item, tableCell: self)
			stackView.addArrangedSubview(label)
			
			// Force full width
			label.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
		}
		
		if let lastLabel = stackView.arrangedSubviews.last, stackView.arrangedSubviews.count > 1 {
			// After layout
			DispatchQueue.main.async {
				lastLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
			}
		}
		
		stackView.invalidateIntrinsicContentSize()
		self.invalidateIntrinsicContentSize()
						
		self.layoutSubtreeIfNeeded()
	}
		
	public override func viewWillDraw() {
		super.viewWillDraw()
	}
	
	public override var intrinsicContentSize: NSSize {
		return stackView?.intrinsicContentSize ?? super.intrinsicContentSize
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
		stackView.updateConstraints()
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
		guard BeatUserDefaults.shared().getBool(BeatSettingRelativeOutlineHeights), let scene else { return 0.0 }
		
		var relativeHeight:CGFloat = 0.0
		let sizeModifier = BeatUserDefaults.shared().getFloat(BeatSettingOutlineFontSizeModifier) * 0.1 + 1
		let modifier = 80.0 * sizeModifier
		
		if let pages = self.outlineView?.editorDelegate.pagination().numberOfPages, pages > 0 {
			// Calculate the relative size of the scene
			relativeHeight = modifier * scene.printedLength
		}
		
		return relativeHeight
	}
}

/*
class BeatOutlineItemContainerView:NSView {
	@IBOutlet weak var outlineCell:BeatOutlineViewCell?
}
*/
