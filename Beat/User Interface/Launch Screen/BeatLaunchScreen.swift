//
//  BeatLaunchScreen.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.3.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatLaunchScreen : NSWindowController {
	
	@IBOutlet var recentFiles: NSOutlineView!
	@IBOutlet var versionField: NSTextField!
	@IBOutlet var recentFilesSource: RecentFiles!
	
	init() {
		super.init(window: nil)
		Bundle.main.loadNibNamed("LaunchScreen", owner: self, topLevelObjects: nil)
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		Bundle.main.loadNibNamed("LaunchScreen", owner: self, topLevelObjects: nil)
	}
	override func close() {
		self.window?.close()
	}
	
	override func awakeFromNib() {
		self.window?.isMovableByWindowBackground = true

		// Set version field value
		var version:String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
		version = "beat " + version
		versionField.stringValue = version
		
		// Reload recent file source + view
		recentFilesSource.reload()
		recentFiles.reloadData()
		
		recentFiles.doubleAction = #selector(self.recentFilesSource.doubleClickDocument(_:))
		recentFiles.target = self.recentFilesSource
	}
}


class BeatLaunchScreenView : NSViewController {
	
	@IBOutlet var recentFiles: NSOutlineView!
	@IBOutlet var versionField: NSTextField!
	@IBOutlet var noRecentFilesLabel: NSTextField?
	var recentFilesSource = RecentFiles()
	
	func close() {
		self.view.window?.close()
	}
	
	override func awakeFromNib() {
		self.view.window?.isMovableByWindowBackground = true

		// Set version field value
		versionField.stringValue =  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
		
		
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
	/*
	@IBAction func openWebResource(sender:BeatURLButton?) {
		guard let url = sender?.url else { return }
		webResources.openURLwithButton(sender: sender)
	}
	 */
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
