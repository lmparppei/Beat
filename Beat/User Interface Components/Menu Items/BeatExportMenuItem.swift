//
//  BeatExportMenuItem.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 29.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatFileExport
import BeatCore

@objc public class BeatFileExportMenuItem:NSMenuItem {
	@IBInspectable public var format:String = ""
	
	override public init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
		super.init(title: string, action: #selector(export), keyEquivalent: "")
		self.target = BeatFileExportManager.shared
	}
	
	required init(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	@objc public func export() {
		
	}
}
