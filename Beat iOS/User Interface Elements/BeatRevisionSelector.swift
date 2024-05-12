//
//  BeatRevisionSelector.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 10.5.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

class BeatRevisionSelector:UIButton
{
	public var revisionLevel = 0 {
		didSet {
			let gen = BeatRevisions.revisionGenerations()[revisionLevel]
			let image = BeatColors.labelImage(forColor: gen.color, size: CGSizeMake(16.0, 16.0))
			
			self.title = NSLocalizedString("revision." + String(revisionLevel+1), tableName: nil, comment: "Revision name")
			self.setImage(image, for: .normal)
		}
	}

	weak var settingController:BeatSettingsViewController?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		let generations = BeatRevisions.revisionGenerations()
		
		// Replace the menu with a generated one
		self.menu = UIMenu(children: [
			UIDeferredMenuElement.uncached { [weak self] completion in
				var items:[UIMenuElement] = []
				
				for i in 0..<generations.count {
					let gen = generations[i]
					
					let image = BeatColors.labelImage(forColor: gen.color, size: CGSizeMake(16.0, 16.0))
					let title = NSLocalizedString("revision." + String(i+1), tableName: nil, comment: "Revision name")
					
					let item = UIAction(title: title, image: image) { item in
						self?.selectGeneration(i)
					}
					
					// Set item state according to current revision level
					item.state = (self?.revisionLevel == i) ? .on : .off
					
					items.append(item)
				}
				
				completion(items)
			}
		])
	}
		
	func selectGeneration(_ level:Int) {
		self.revisionLevel = level
		settingController?.selectRevisionGeneration(self)
	}
}
