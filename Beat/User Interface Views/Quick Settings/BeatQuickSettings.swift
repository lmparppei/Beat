//
//  BeatQuickSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

fileprivate let padding = 6.0

@objc protocol BeatQuickSettingsDelegate:BeatEditorDelegate {
	//func toggleSceneLabels(_ sender:Any?)
	//func togglePageNumbers(_ sender:Any?)
	func toggleRevisionMode(_ sender:Any?)
	func toggleReview(_ sender:Any?)
	func toggleTagging(_ sender:Any?)
}

class BeatDesktopQuickSettings:NSViewController {
	@objc weak var delegate:BeatQuickSettingsDelegate?
	
	@IBOutlet weak var stackView:BeatStackView?
	@IBOutlet weak var additionalSettings:BeatStackView?
	
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

		// Load any additional settings required by the stylesheet
		addAdditionalSettings()
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
		
		// Remove placeholder menu items and append all generations
		if let revisionColorPopup {
			revisionColorPopup.removeAllItems()
			
			var i = 1
			for generation in BeatRevisions.revisionGenerations() {
				revisionColorPopup.addItem(withTitle: NSLocalizedString("revision.\(i)", comment: generation.color))
				revisionColorPopup.lastItem?.image = BeatColors.labelImage(forColor: generation.color, size: CGSizeMake(16, 16))
				
				i += 1
			}
			
			revisionColorPopup.selectItem(at: delegate.revisionLevel)
		}
		
		if delegate.mode == .ReviewMode {
			reviewMode?.checked = true
		}
		else if delegate.mode == .TaggingMode {
			taggingMode?.checked = true
		}
	}
	
	/// This currently only supports *two* settings, but it's built this way to be open to adustments. At some point we can control these via BeatCSS.
	func addAdditionalSettings() {
		guard let settings = self.delegate?.editorStyles.document.additionalSettings,
			  let container = self.additionalSettings
		else { return }
		if settings.count == 0 { return }
		
		container.addView(BeatQuickSettingSeparator.newSeparator())
		
		for setting in settings {
			var item:NSView?
			
			if setting == "novelLineHeightMultiplier" {
				item = self.segmentedSetting(setting: setting, segments: ["2.0", "1.5"], values: [2.0, 1.5], validation: { value in
					let v = value as? Float ?? 2.0
					return (v < 2.0) ? 1 : 0
				}) { [weak self] value, actualValue in
					self?.delegate?.documentSettings.set(setting, as: actualValue ?? 2.0)
					self?.delegate?.reloadStyles()
				}
				
			} else if setting == "novelContentAlignment" {
				var icons:[NSImage] = []
				
				if #available(macOS 11.0, *) {
					if let leftIcon = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Left align"), let justifyIcon = NSImage(systemSymbolName: "text.justifyleft", accessibilityDescription: "Justify") {
						icons = [leftIcon, justifyIcon]
					}
				}
				
				item = self.segmentedSetting(setting: setting, segments: ["", ""], icons: icons, values: ["", "justify"], validation: { value in
					let v = value as? String ?? ""
					return (v == "justify") ? 1 : 0
				}) { [weak self] value, actualValue in
					self?.delegate?.documentSettings.set(setting, as: actualValue ?? "")
					self?.delegate?.reloadStyles()
					self?.delegate?.formatting.formatAllAsynchronously()
				}
			}
			
			if let settingItem = item { container.addView(settingItem) }
		}
		
		container.updateSize()
		container.frame.origin.y -= container.frame.size.height
		
		// Update the view height
		self.view.frame.size.height += container.frame.height + 6.0
		
		self.view.addSubview(container)
	}
	
	func setupQuickSettings() {
		guard let delegate = self.delegate else { return }
		let revisions = BeatRevisions.revisionGenerations()
				
		let items = [
			BeatQuickSettingItem.newToggle("Show Scene Numbers", key: BeatSettingShowSceneNumbers, handler: { value, _ in
				delegate.showSceneNumberLabels = !delegate.showSceneNumberLabels
				delegate.getTextView().needsDisplay = true
			}),
			BeatQuickSettingItem.newToggle("Show Page Numbers", key: BeatSettingShowPageNumbers, handler: { value, _ in
				delegate.showPageNumbers = !delegate.showPageNumbers
				delegate.getTextView().needsDisplay = true
			}),
			BeatQuickSettingItem.newToggle("Dark Mode", initialValue: delegate.isDark().intValue, handler: { value, _ in
				if let appDelegate = NSApplication.shared.delegate as? BeatAppDelegate {
					appDelegate.toggleDarkMode()
				}
			}),
			BeatQuickSettingSeparator.newSeparator(),
			BeatQuickSettingItem.newDropdown("Paper Size",
											 items: [NSMenuItem(title: "A4", action: nil, keyEquivalent: ""),
													 NSMenuItem(title: "US Letter", action: nil, keyEquivalent: "")],
											 value: delegate.pageSize.rawValue,
											 handler: { [weak self] selection, _ in
												 self?.delegate?.pageSize = BeatPaperSize(rawValue: selection as? Int ?? 0) ?? .A4
											 }),
			BeatQuickSettingSeparator.newSeparator(),
			BeatQuickSettingItem.newToggle("Revision Mode", initialValue: delegate.revisionMode.intValue, handler: { [weak self] value, _ in
				self?.delegate?.toggleRevisionMode(nil)
			}),
			BeatQuickSettingItem.newDropdown("Generation",
											 items: revisions.map({ revision in BeatColorMenuItem(color: revision.color) }),
											 value: delegate.revisionLevel,
											 size: .small,
											 handler: { [weak self] selection, _ in
												 let i = selection as? Int ?? 0
												 self?.delegate?.revisionLevel = i
											 })
		]
		
		for item in items {
			stackView?.addView(item)
		}
	}
	
	@IBAction func toggleValue(sender:ITSwitch?) {
		guard let button = sender, let delegate else { return }
		
		switch button {
		case sceneNumbers:
			delegate.showSceneNumberLabels = !delegate.showSceneNumberLabels; break
		case pageNumbers:
			delegate.showPageNumbers = !delegate.showPageNumbers; break
		case revisionMode:
			self.delegate?.toggleRevisionMode(nil); break
		case reviewMode:
			self.delegate?.toggleReview(nil); break
		case darkMode:
			if let appDelegate = NSApplication.shared.delegate as? BeatAppDelegate {
				appDelegate.toggleDarkMode()
			}
			break
		case taggingMode:
			self.delegate?.toggleTagging(nil); break
		default:
			break
		}
		
		delegate.getTextView().needsDisplay = true
		self.updateSettings()
	}
	
	@IBAction func selectRevisionColor(sender:NSPopUpButton) {
		self.delegate?.revisionLevel = sender.indexOfSelectedItem
		self.updateSettings()
	}
	
	@IBAction func selectPaperSize(sender:NSPopUpButton) {
		self.delegate?.pageSize =  BeatPaperSize(rawValue: sender.indexOfSelectedItem) ?? .A4
		self.updateSettings()
	}
}


// MARK: - Additional setting getters and setters

extension BeatDesktopQuickSettings {
	func segmentedSetting(setting:String, segments:[String], icons:[NSImage] = [], values:[Any], validation:(Any?) -> Int, handler:@escaping (Any, Any?) -> Void) -> NSView {
		let value = delegate?.documentSettings.get(setting)
		let label = NSLocalizedString("quickSettings." + setting, comment: "")
		let selected = validation(value)
		
		let item = BeatQuickSettingItem.newSegment(label, segments: segments, icons: icons, values:values, value: selected, handler: handler)
		
		return item
	}
}


// MARK: - Additional setting views

enum BeatQuickSettingViewType {
	case none
	case separator
	case toggle
	case dropdown
	case segment
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
	
	func updateSize() {
		guard let lastView = self.subviews.last else { return }
		
		let maxY = lastView.frame.maxY
		
		var frame = self.frame
		frame.size.height = maxY
		
		self.frame = frame
	}
}

class BeatQuickSettingItem:NSView {
	var type:BeatQuickSettingViewType = .none
	var handler:((Any, Any?) -> Void)?
	var control:Any?
	
	var segmentedValues:[Any] = []
	
	override var isFlipped: Bool { return true }
	
	static var defaultWidth = 172.0
	
	init(frame frameRect: NSRect, type:BeatQuickSettingViewType = .none, handler:((Any, Any?) -> Void)? = nil) {
		self.handler = handler
		self.type = type
		super.init(frame: frameRect)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	class func newToggle(_ text:String, key:String = "", documentSetting:Bool = false, initialValue:Int = -1, handler:@escaping (Any, Any?) -> Void) -> NSView {
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
	
	class func newDropdown(_ text:String, items:[NSMenuItem], value:Int, size:NSControl.ControlSize = .regular, handler:@escaping (Any, Any?) -> Void) -> NSView {
		
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
	
	class func newSegment(_ text:String, segments:[String], icons:[NSImage] = [], values:[Any], value:Int, handler:@escaping (Any, Any?) -> Void) -> NSView {
		let item = BeatQuickSettingItem(frame: NSMakeRect(0.0, 0.0, BeatQuickSettingItem.defaultWidth, 22.0), type: .segment, handler: handler)
		
		let segmentedControl = NSSegmentedControl(frame: NSMakeRect(90.0, 0.0, 90.0, 22.0))
		segmentedControl.frame.origin.x = item.frame.size.width - segmentedControl.frame.width + padding * 2
		
		segmentedControl.segmentCount = segments.count
		segmentedControl.target = item
		segmentedControl.action = #selector(runAction)
		segmentedControl.sendAction(on: .leftMouseUp)
		
		item.segmentedValues = values
		item.control = segmentedControl
		item.addSubview(segmentedControl)
		
		for i in 0..<segments.count {
			segmentedControl.setLabel(segments[i], forSegment: i)
			if (i < icons.count) {
				segmentedControl.setImage(icons[i], forSegment: i)
			}
		}
		
		let label = NSTextField(labelWithString: text)
		label.frame.origin = CGPoint(x: padding, y: (item.frame.height - label.frame.height) / 2)
		item.addSubview(label)
		
		segmentedControl.setSelected(true, forSegment: value)
		
		return item
	}
	
	@IBAction func runAction(_ sender:BeatQuickSettingItem) {
		var value:Any?
		var actualValue:Any?
		
		if type == .toggle, let button = control as? ITSwitch {
			value = button.checked
		} else if type == .dropdown, let popup = control as? NSPopUpButton, let selected = popup.selectedItem {
			value = popup.itemArray.firstIndex(of: selected)
		} else if type == .segment, let segment = control as? NSSegmentedControl {
			value = segment.selectedSegment
			actualValue = segmentedValues[segment.selectedSegment]
		}
		
		if let handler = self.handler, let v = value {
			handler(v, actualValue)
		}
	}
	
}
class BeatQuickSettingSeparator:NSBox {
	class func newSeparator() -> NSView {
		let view = NSView(frame: NSMakeRect(0.0, 0.0, BeatQuickSettingItem.defaultWidth, 14.0))
		let box = NSBox(frame: NSMakeRect(0.0, 7.0, BeatQuickSettingItem.defaultWidth, 1.0))
		box.boxType = .separator
		box.autoresizingMask = .width
		
		view.addSubview(box)
		return view
	}
}

