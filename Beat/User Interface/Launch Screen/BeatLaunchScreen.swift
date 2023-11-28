//
//  BeatLaunchScreen.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.3.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatLaunchScreenView : NSViewController {
	
	@IBOutlet weak var recentFiles: NSOutlineView!
	@IBOutlet weak var versionField: NSTextField!
	@IBOutlet weak var noRecentFilesLabel: NSTextField?
	var recentFilesSource = RecentFiles()
	
	@IBOutlet weak var supportButton: BeatURLButton?
	
	func close() {
		self.view.window?.close()
	}
	
	override func awakeFromNib() {
		self.view.window?.isMovableByWindowBackground = true

		// Set version field value
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
		versionField.stringValue = version
		
		recentFiles.dataSource = recentFilesSource
		recentFiles.delegate = recentFilesSource

		// Reload recent file source + view
		recentFilesSource.reload()
		recentFiles.reloadData()
		
		if (recentFiles.numberOfRows == 0) {
			noRecentFilesLabel?.isHidden = false
		} else {
			noRecentFilesLabel?.isHidden = true
		}
		
		recentFiles.doubleAction = #selector(self.recentFilesSource.doubleClickDocument(_:))
		recentFiles.target = self.recentFilesSource
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		guard let supportButton = self.supportButton else { return }
		
		// Add the version number if needed
		if !supportButton.website.contains("?version") {
			let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
			supportButton.website += "?version=" + version
			#if ADHOC
				supportButton.website += "&adhoc=1"
			#endif
		}
	}
}

class SameWindowStoryboardSegue: NSStoryboardSegue {
	override func perform() {
		// Get the source and destination view controllers
		guard let sourceViewController = sourceController as? NSViewController,
			  let destinationViewController = destinationController as? NSViewController else {
			return
		}
		
		// Get the window controller
		guard let window = sourceViewController.view.window else {
			return
		}
		
		// Replace the content view controller with the destination view controller
		window.contentViewController = destinationViewController
		window.makeCentered()
	}
}

@objc extension NSWindow {
	func makeCentered() {
		var frame = self.frame
		guard let screen = self.screen?.frame.size else { return }
		
		frame.origin.x = (screen.width - frame.size.width) / 2
		frame.origin.y = (screen.height - frame.size.height) / 2
		
		self.setFrame(frame, display: true)
	}
}

/*
 
 
 
 */
