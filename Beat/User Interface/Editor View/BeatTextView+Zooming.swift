//
//  BeatTextView+Zooming.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
//  This was an attempt in translating zooming code to Swift and modularizing it.
//  Doesn't work.

import Foundation

/*
extension BeatTextView {
		
	@objc func adjustZoomLevelBy(value:CGFloat) {
		let newMagnification = self.zoomLevel
		adjustZoomLevel(newMagnification)
	}
	
	func clamp(_ d:Double, min:Double, max:Double) -> Double {
		let t:Double = d < min ? min : d
		return t > max ? max : t
	}
	
	@objc func adjustZoomLevel(_ level:CGFloat) {
		if (self.scaleFactor == 0) { self.scaleFactor = self.zoomLevel }
		
		let newZoom = clamp(level, min: 0.8, max: 1.5)
		let oldZoom = self.zoomLevel
		
		if (oldZoom != level) {
			self.zoomLevel = newZoom
			
			let scrollPosition = self.enclosingScrollView!.contentView.documentVisibleRect.origin
			
			self.adjustScaleFactor(self.zoomLevel)
			self.editorDelegate.updateLayout()
			self.enclosingScrollView!.contentView.scroll(scrollPosition)
			self.editorDelegate.ensureLayout()
			
			self.needsDisplay = true
			self.enclosingScrollView?.needsDisplay = true
			
			// For some reason, clip view might get the wrong height after magnifying. No idea what's going on.
			var clipFrame = self.enclosingScrollView!.contentView.frame;
			clipFrame.size.height = self.enclosingScrollView!.contentView.superview!.frame.size.height * self.zoomLevel;
			self.enclosingScrollView!.contentView.frame = clipFrame;
			
			self.editorDelegate.ensureLayout()
		}
		
		BeatUserDefaults.shared().save(self.zoomLevel, forKey: "zoomLevel")
		
		editorDelegate.updateLayout()
		editorDelegate.ensureLayout()
		editorDelegate.ensureCaret()
	}
	
	@objc func adjustScaleFactor(_ newScaleFactor:Double) {
		let oldScaleFactor = self.scaleFactor;
		
		if (self.scaleFactor != newScaleFactor)
		{
			var curDocFrameSize:NSSize = NSSize()
			var newDocBoundsSize:NSSize = NSSize()
			let clipView = self.superview!;
			
			self.scaleFactor = newScaleFactor;
			
			// Get the frame.  The frame must stay the same.
			curDocFrameSize = clipView.frame.size;
			
			// The new bounds will be frame divided by scale factor
			newDocBoundsSize.width = curDocFrameSize.width;
			newDocBoundsSize.height = curDocFrameSize.height / newScaleFactor;
			
			let newFrame = NSMakeRect(0, 0, newDocBoundsSize.width, newDocBoundsSize.height);
			clipView.frame = newFrame;
		}
		
		self.scaleChanged(oldScale:oldScaleFactor, newScale:newScaleFactor);
		
		// Set minimum size for text view when Outline view size is dragged
		self.editorDelegate.setSplitHandleMinSize(CGFloat(self.editorDelegate.documentWidth) * self.zoomLevel)
	}
	
	func scaleChanged(oldScale:Double, newScale:Double) {
		// Thank you, Mark Munz @ stackoverflow
		let scaler = newScale / oldScale;
		
		self.scaleUnitSquare(to: NSSize(width: scaler, height: scaler))
		self.layoutManager?.ensureLayout(for: self.textContainer!)
		
		self.scaleFactor = newScale;
	}
	
	// MARK: Zoom in / out
	
	@objc func zoom(_ zoomIn:Bool) {
		// For some reason, setting 1.0 scale for NSTextView causes weird sizing bugs, so we will use something that will never produce 1.0...... omg lol help
		var newZoom = self.zoomLevel
		if (zoomIn) { newZoom += 0.04 }
		else { newZoom -= 0.04 }
		
		adjustZoomLevel(newZoom)
	}
	
	@objc func setupZoom() {
		// Reset zoom to saved setting
		var newZoom = BeatUserDefaults.shared().getFloat("zoomLevel")
		if (newZoom <= 0.1) { newZoom = 0.97 }
		
		self.scaleFactor = 1.0
		adjustScaleFactor(newZoom)
		
		self.editorDelegate.updateLayout()
	}
	
	@objc func resetZoom() {
		let newZoom = 0.97
		adjustZoomLevel(newZoom)
	}
}
*/
