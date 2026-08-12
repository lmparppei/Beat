//
//  Document+VersionControl.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 17.4.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension Document {
	@objc func hasVersionControl() -> Bool {
		let vc = BeatVersionControl(delegate: self)
		return vc.hasVersionControl()
	}
	
	@IBAction func commit(_ sender: Any?) {
		let popover = BeatVersionControl.commitPrompt(delegate: self) { _ in
			Swift.print("Commit successful")
		}
		
		if let view = self.documentWindow?.contentView {
			let bounds = CGRectMake(view.bounds.origin.x, view.bounds.origin.y + view.bounds.height - 2, view.bounds.width, 1)
			popover.show(relativeTo: bounds, of: view, preferredEdge: .minY)
		}
	}
	
	@objc func showCommitModal(callback: @escaping () -> Void) {
		BeatVersionControl.commitPromptModal(delegate: self) { _ in
			callback()
		}
	}
}
