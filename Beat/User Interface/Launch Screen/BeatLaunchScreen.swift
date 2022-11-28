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

/*
 
 
 
 */
