//
//  BeatTagManager.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

protocol BeatTagManagerView {
	var delegate:BeatEditorDelegate? { get set }
	func reload()
}

@objcMembers
class BeatTagManager:NSWindowController {
	weak var delegate:BeatEditorDelegate?

	class func openTagEditor(delegate:BeatEditorDelegate) -> NSWindowController? {
		let storyboard = NSStoryboard(name: "BeatTagEditor", bundle: .main)
		let wc = storyboard.instantiateController(withIdentifier: "TagEditorWindow") as? BeatTagManager
		
		wc?.delegate = delegate
		wc?.window?.parent = delegate.documentWindow
		wc?.window?.level = .modalPanel
		
		wc?.window?.setFrame(CGRectMake(0.0, 0.0, 600, 400), display: true)
		wc?.window?.center()
		wc?.showWindow(wc?.window)
		
		let id = wc?.window?.toolbar?.items.first?.itemIdentifier
		wc?.window?.toolbar?.selectedItemIdentifier = id

		wc?.setup()
		
		return wc
	}
	
	class func tagIcon(type:BeatTagType) -> NSImage {
		var image:NSImage?
		
		if #available(macOS 11.0, *) {
			let i = NSNumber(value: type.rawValue)
			let iconName = BeatTagging.tagIcons()[i] ?? ""
			
			image = NSImage.init(systemSymbolName: iconName, accessibilityDescription: "")
		} else {
			let color = BeatTagging.color(for: type)
			image = BeatColors.labelImage(forColorValue: color, size: CGSizeMake(20.0, 20.0))
		}
		
		return image ?? NSImage(size: CGSize(width: 20.0, height: 20.0))
	}
		
	func setup() {
		if let tabViewController = self.contentViewController as? NSTabViewController {
			for tab in tabViewController.tabViewItems {
				var tagVC = tab.viewController as? BeatTagManagerView
				tagVC?.delegate = delegate
				tagVC?.reload()
			}
		}
		
		delegate?.addChangeListener({ [weak self] _ in self?.reload() }, owner: self)
	}
	
	@IBAction func selectTab(_ sender:NSToolbarItem?) {
		if let i = sender?.tag {
			self.tabView?.tabView.selectTabViewItem(at: i)
		}
	}
	
	var tabView:NSTabViewController? {
		return self.contentViewController as? NSTabViewController
	}
	
	var tagViews:[BeatTagManagerView] {
		var views:[BeatTagManagerView] = []
		
		if let tabView {
			for tab in tabView.tabViewItems {
				if let tagVC = tab.viewController as? BeatTagManagerView {
					views.append(tagVC)
				}
			}
		}
		
		return views
	}
		
	func reload() {
		for view in self.tagViews {
			view.reload()
		}
	}
	
	override func close() {
		self.delegate?.removeChangeListeners(for: self)
		super.close()
	}
}
