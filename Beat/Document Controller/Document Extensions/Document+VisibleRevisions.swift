//
//  Document+VisibleRevisions.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.9.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore

class BeatVisibleRevisionsMenu:NSMenu, NSMenuDelegate {
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.delegate = self
		
		let generations = BeatRevisions.revisionGenerations()
		for generation in generations {
			let image = BeatColors.labelImage(forColor: generation.color, size: CGSizeMake(15.0, 15.0))
			
			let title = BeatLocalization.localizedString(forKey: "revision.\(generation.level+1)")
			let item = BeatVisibleRevisionMenuItem(title: title, action: #selector(Document.toggleVisibleRevision), keyEquivalent: "")
			item.image = image
			item.tag = generation.level
			
			self.addItem(item)
		}
	}
}

@objc class BeatVisibleRevisionMenuItem:NSMenuItem {
	@objc func validateWithVisibleRevisions(_ visibleRevisions:[Int]) {
		if (visibleRevisions.contains(self.tag)) {
			self.state = .off
		} else {
			self.state = .on
		}
	}
}
