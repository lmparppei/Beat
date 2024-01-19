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
	
	@IBOutlet weak var stackView:BeatStackView?
	
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
		
		// Page size is an integer enum, so we'll resort to this hack.
		// First item is A4, second item US Letter
		pageSizePopup?.selectItem(at: delegate.pageSize.rawValue)
		
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
	
	func setupQuickSettings() {
		guard let delegate = self.delegate else { return }
		let revisions = BeatRevisions.revisionColors()
				
		let items = [
			BeatQuickSettingItem.newToggle("Show Scene Numbers", key: BeatSettingShowSceneNumbers, handler: { value in
				self.delegate?.toggleSceneLabels(nil)
			}),
			BeatQuickSettingItem.newToggle("Show Page Numbers", key: BeatSettingShowPageNumbers, handler: { value in
				self.delegate?.togglePageNumbers(nil)
			}),
			BeatQuickSettingItem.newToggle("Dark Mode", initialValue: delegate.isDark().intValue, handler: { [weak self] value in
				self?.delegate?.toggleDarkMode(nil)
			}),
			BeatQuickSettingSeparator.newSeparator(),
			BeatQuickSettingItem.newDropdown("Paper Size",
											 items: [NSMenuItem(title: "A4", action: nil, keyEquivalent: ""),
													 NSMenuItem(title: "US Letter", action: nil, keyEquivalent: "")],
											 value: delegate.pageSize.rawValue,
											 handler: { [weak self] selection in
												 self?.delegate?.pageSize = BeatPaperSize(rawValue: selection as? Int ?? 0) ?? .A4
											 }),
			BeatQuickSettingSeparator.newSeparator(),
			BeatQuickSettingItem.newToggle("Revision Mode", initialValue: delegate.revisionMode.intValue, handler: { [weak self] value in
				self?.delegate?.toggleRevisionMode(nil)
			}),
			BeatQuickSettingItem.newDropdown("Generation",
											 items: revisions.map({ color in BeatColorMenuItem(color: color) }),
											 value: revisions.firstIndex(of: delegate.revisionColor) ?? 0,
											 size: .small,
											 handler: { [weak self] selection in
												 let i = selection as? Int ?? 0
												 self?.delegate?.revisionColor = revisions[i]
											 })
		]
		
		for item in items {
			stackView?.addView(item)
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

enum BeatQuickSettingViewType {
	case none
	case separator
	case toggle
	case dropdown
}

class BeatStackView:NSView {
	override var isFlipped: Bool { return true }
	
	var margin = 8.0
	
	func addView(_ view:NSView) {
		var y = 0.0
		
		if let lastView = self.subviews.last {
			y = lastView.frame.maxY + margin
		}
		
		view.frame.size.width = self.frame.size.width
		view.frame.origin = CGPoint(x: 0.0, y: y)
		
		
		self.addSubview(view)
	}
}

class BeatQuickSettingItem:NSView {
	var type:BeatQuickSettingViewType = .none
	var handler:((Any) -> Void)?
	
	var control:Any?
	override var isFlipped: Bool { return true }
	
	static var defaultWidth = 172.0
	static var padding = 5.0
	
	init(frame frameRect: NSRect, type:BeatQuickSettingViewType = .none, handler:((Any) -> Void)? = nil) {
		self.handler = handler
		self.type = type
		super.init(frame: frameRect)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	class func newToggle(_ text:String, key:String = "", documentSetting:Bool = false, initialValue:Int = -1, handler:@escaping (Any) -> Void) -> NSView {
		let item = BeatQuickSettingItem(frame: NSMakeRect(0.0, 0.0, BeatQuickSettingItem.defaultWidth, 22.0), type: .toggle, handler: handler)
		
		let button = ITSwitch(frame: NSMakeRect(padding, 0.0, 35.0, 22.0), settingKey: key, documentSetting: documentSetting)
		button.action = #selector(runAction)
		button.target = item
		
		if initialValue >= 0 {
			button.checked = (initialValue == 1) ? true : false
		}
		
		item.control = button
		item.addSubview(button)
		
		let label = NSTextField(labelWithString: text)
		label.frame.origin = CGPoint(x: button.frame.maxX + 10.0, y: (item.frame.height - label.frame.height) / 2)
		item.addSubview(label)
		
		return item
	}
	
	class func newDropdown(_ text:String, items:[NSMenuItem], value:Int, size:NSControl.ControlSize = .regular, handler:@escaping (Any) -> Void) -> NSView {
		
		let popup = NSPopUpButton(frame: NSMakeRect(90.0, 0.0, 115.0, 22.0))
		popup.controlSize = size
		popup.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: size))
		items.forEach { popup.menu?.items.append($0) }
		
		let item = BeatQuickSettingItem(frame: NSMakeRect(0.0, 0.0, BeatQuickSettingItem.defaultWidth, popup.frame.size.height), type: .dropdown, handler: handler)
		
		let offset = (size == .regular) ? 4.0 : 2.0
		let label = NSTextField(labelWithString: text)
		label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: (size == .small) ? .mini : .regular))
		label.controlSize = size
		label.sizeToFit()
		label.frame.origin = CGPoint(x: padding, y: (popup.frame.height - offset - label.frame.height) / 2)
		
		popup.target = item
		popup.action = #selector(runAction)
		
		item.control = popup
		item.addSubview(popup)
		item.addSubview(label)
		
		return item
	}
	
	@IBAction func runAction(_ sender:BeatQuickSettingItem) {
		var value:Any?
		
		if type == .toggle, let button = control as? ITSwitch {
			value = button.checked
		} else if type == .dropdown, let popup = control as? NSPopUpButton, let selected = popup.selectedItem {
			value = popup.itemArray.firstIndex(of: selected)
		}
		
		if let handler = self.handler, value != nil {
			handler(value!)
		}
	}
	
}
class BeatQuickSettingSeparator:NSBox {
	class func newSeparator() -> NSView {
		let view = NSView(frame: NSMakeRect(0.0, 0.0, BeatQuickSettingItem.defaultWidth, 18.0))
		let box = NSBox(frame: NSMakeRect(0.0, 8.5, BeatQuickSettingItem.defaultWidth, 1.0))
		box.boxType = .separator
		box.autoresizingMask = .width
		
		view.addSubview(box)
		return view
	}
}
