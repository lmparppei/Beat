//
//  BeatRevisionManagement.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 20.11.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
//import BeatCore
import BeatCore.BeatRevisions

@objc extension BeatRevisions {
	
	//weak var delegate:BeatEditorDelegate?
	
	@objc @IBAction func downgradeRevisions(_ sender:AnyObject?) {
		guard let delegate = self.delegate else {
			print("No editor delegate set")
			return
		}
		
		// Alert box
		let input = NSAlert()
		input.messageText = BeatLocalization.localizedString(forKey: "revisions.downgrade.title")
		input.informativeText = BeatLocalization.localizedString(forKey: "revisions.downgrade.info")
		
		// Buttons
		input.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.ok"))
		input.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.cancel"))

		// Accessory view
		let accessoryView = NSView(frame: NSMakeRect(0, 0, 250, 50))
		
		// Label
		let label = NSTextField(labelWithString: BeatLocalization.localizedString(forKey: "revisions.downgrade.from"))
		accessoryView.addSubview(label)
		label.frame = NSMakeRect((accessoryView.frame.width - label.frame.width) / 2.0, accessoryView.frame.height - label.frame.height, label.frame.width, label.frame.height)
		
		// Dropdown
		let dropdown = NSPopUpButton(frame: NSMakeRect(0.0, 0.0, 250.0, 30.0))
		accessoryView.addSubview(dropdown)
		
		input.accessoryView = accessoryView
		
		let colors = BeatRevisions.revisionColors()
		for color in colors {
			dropdown.addItem(withTitle: BeatLocalization.localizedString(forKey: "color." + color))
			
			if let item = dropdown.itemArray.last {
				item.image = NSImage(named: "Color_" + color.capitalized)
			}
		}
				
		input.beginSheetModal(for: delegate.documentWindow!) { response in
			if response != .alertFirstButtonReturn {
				return
			}
			
			// Downgrade each revision
			self.downgrade(fromRevisionIndex: dropdown.indexOfSelectedItem)
		}
	}
	
	@objc @IBAction func convertRevisions(_ sender:AnyObject?) {
		guard let delegate = self.delegate else {
			print("No editor delegate set")
			return
		}
		
		// Alert box
		let input = NSAlert()
		input.messageText = BeatLocalization.localizedString(forKey: "revisions.convert.title")
		input.informativeText = BeatLocalization.localizedString(forKey: "revisions.convert.info")
		
		// Buttons
		input.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.ok"))
		input.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.cancel"))

		// Accessory view
		let accessoryView = NSView(frame: NSMakeRect(0, 0, 250, 125))
		
		let stack = NSStackView(frame: accessoryView.frame)
		stack.orientation = .vertical
		
		let labelFrom = NSTextField(labelWithString: BeatLocalization.localizedString(forKey: "revisions.convert.from"))
		let dropdownFrom = NSPopUpButton(frame: NSMakeRect(0.0, 0.0, 250.0, 30.0))
		
		let generations = BeatRevisions.revisionGenerations()
						
		let labelTo = NSTextField(labelWithString: BeatLocalization.localizedString(forKey: "revisions.convert.to"))
		let dropdownTo = NSPopUpButton(frame: NSMakeRect(0.0, 0.0, 250.0, 30.0))
		
		let selectedTextCheckbox = NSButton(checkboxWithTitle: BeatLocalization.localizedString(forKey: "revisions.convert.onlySelectedRange"), target: nil, action: nil)
		
		stack.addArrangedSubview(labelFrom)
		stack.addArrangedSubview(dropdownFrom)
		stack.addArrangedSubview(labelTo)
		stack.addArrangedSubview(dropdownTo)
		stack.addArrangedSubview(selectedTextCheckbox)
		
		accessoryView.addSubview(stack)
		input.accessoryView = accessoryView

		// Add items
		dropdownTo.addItem(withTitle: BeatLocalization.localizedString(forKey: "revisions.convert.remove"))
		
		for gen in generations {
			let color = gen.color
			
			dropdownFrom.addItem(withTitle: BeatLocalization.localizedString(forKey: "color." + color))
			dropdownFrom.itemArray.last?.image = NSImage(named: "Color_" + color.capitalized)
			
			dropdownTo.addItem(withTitle: BeatLocalization.localizedString(forKey: "color." + color))
			dropdownTo.itemArray.last?.image = NSImage(named: "Color_" + color.capitalized)
		}

		input.beginSheetModal(for: delegate.documentWindow!) { response in
			if response != .alertFirstButtonReturn {
				return
			}
			
			// Downgrade each revision
			let originalGen = BeatRevisions.revisionGenerations()[dropdownFrom.indexOfSelectedItem]
			
			var targetGen:BeatRevisionGeneration?
			if (dropdownTo.indexOfSelectedItem > 0) {
				targetGen = BeatRevisions.revisionGenerations()[dropdownTo.indexOfSelectedItem - 1]
			}
			
			if selectedTextCheckbox.state == .on {
				// Convert selection only
				self.convert(originalGen, to: targetGen, range: delegate.selectedRange)
			} else {
				// Convert the whole text
				self.convert(originalGen, to: targetGen)
			}
		}

	}
}
