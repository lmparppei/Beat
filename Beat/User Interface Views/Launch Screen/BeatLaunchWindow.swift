//
//  BeatLaunchWindow.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 11.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

@objc class BeatLaunchWindow:NSWindow {

	override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
		super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
		
		titlebarAppearsTransparent = true
		isMovableByWindowBackground = true
		isReleasedWhenClosed = false
		title = ""
		
		if #available(macOS 10.14, *) {
			appearance = NSAppearance(named: .darkAqua)
		}
	}
	
	override var contentViewController: NSViewController? {
		didSet {
			if let cv = self.contentViewController {
				var frame = self.frame
				frame.size = cv.view.frame.size
				self.setFrame(frame, display: true)
				
				self.makeCentered()
				self.makeKeyAndOrderFront(nil)
			}
		}
	}
}
