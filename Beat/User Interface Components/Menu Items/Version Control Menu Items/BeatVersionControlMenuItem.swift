//
//  BeatVersionControlMenuItem.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

class BeatVersionControlMenuItem:NSMenuItem, BeatMenuItemValidationInstance {
	func validate(delegate: any BeatEditorDelegate) -> Bool {
		let vc = BeatVersionControl(delegate: delegate)
		if self.action == #selector(beginVersionControl) {
			return !vc.hasVersionControl()
		}
		else if self.action == #selector(addCommit) {
			return vc.hasVersionControl()
		}
		
		
		return false
	}
	
	@objc fileprivate func beginVersionControl() {}
	@objc fileprivate func addCommit() {}
}
