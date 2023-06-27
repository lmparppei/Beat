//
//  BeatQuickSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

@objc protocol BeatQuickSettingsDelegate:BeatEditorDelegate {
	func toggleSceneLabels(_ sender:Any?)
	func togglePageNumbers(_ sender:Any?)
	func toggleRevisionMode(_ sender:Any?)
	func toggleDarkMode(_ sender:Any?)
	func toggleReview(_ sender:Any?)
	func toggleTagging(_ sender:Any?)
}

class BeatDesktopQuickSettings:NSViewController {
	@objc weak var delegate:BeatQuickSettingsDelegate?
	
	@IBOutlet weak var sceneNumbers:ITSwitch?
	@IBOutlet weak var pageNumbers:ITSwitch?
	@IBOutlet weak var revisionMode:ITSwitch?
	@IBOutlet weak var taggingMode:ITSwitch?
	@IBOutlet weak var darkMode:ITSwitch?
	@IBOutlet weak var reviewMode:ITSwitch?
	
	@IBOutlet weak var revisionColorPopup:NSPopUpButton?
	@IBOutlet weak var pageSizePopup:NSPopUpButton?
	
	init() {
		super.init(nibName: "BeatQuickSettings", bundle: Bundle.main)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		self.updateSettings()
	}
	
	func updateSettings() {
		guard let delegate = self.delegate else { return }
		
		sceneNumbers?.checked = delegate.showSceneNumberLabels
		pageNumbers?.checked = delegate.showPageNumbers
		revisionMode?.checked = delegate.revisionMode

		darkMode?.checked = delegate.isDark()
		
		if pageSizePopup != nil {
			// Page size is an integer enum, so we'll resort to this hack.
			// First item is A4, second item US Letter
			pageSizePopup!.selectItem(at: delegate.pageSize.rawValue)
		}
		
		if revisionColorPopup != nil {
			for item in revisionColorPopup!.itemArray {
				guard let cItem = item as? BeatColorMenuItem else { continue }
				
				if cItem.colorKey.lowercased() == delegate.revisionColor.lowercased() {
					revisionColorPopup?.select(item)
				}
			}
		}
		
		if delegate.mode == .ReviewMode {
			reviewMode?.checked = true
		}
		else if delegate.mode == .TaggingMode {
			taggingMode?.checked = true
		}
	}
	
	@IBAction func toggleValue(sender:ITSwitch?) {
		guard let button = sender else { return }
		
		switch button {
		case sceneNumbers:
			self.delegate?.toggleSceneLabels(nil); break
		case pageNumbers:
			self.delegate?.togglePageNumbers(nil); break
		case revisionMode:
			self.delegate?.toggleRevisionMode(nil); break
		case reviewMode:
			self.delegate?.toggleReview(nil); break
		case darkMode:
			self.delegate?.toggleDarkMode(nil); break
		case taggingMode:
			self.delegate?.toggleTagging(nil); break
		default:
			break
		}
		
		self.updateSettings()
	}
	
	@IBAction func selectRevisionColor(sender:NSPopUpButton) {
		guard let item = sender.selectedItem as? BeatColorMenuItem else { return }
		self.delegate?.revisionColor = item.colorKey
		
		self.updateSettings()
	}
	
	@IBAction func selectPaperSize(sender:NSPopUpButton) {
		self.delegate?.pageSize =  BeatPaperSize(rawValue: sender.indexOfSelectedItem) ?? .A4
		self.updateSettings()
	}
}
