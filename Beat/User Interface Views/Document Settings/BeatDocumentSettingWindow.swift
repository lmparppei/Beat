//
//  BeatDocumentSettingView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 29.10.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc class BeatDocumentSettingWindow:NSWindowController {
	@IBOutlet weak var pageSize:NSPopUpButton?
	@IBOutlet weak var styleMenu:NSPopUpButton?
	
	@IBOutlet weak var sceneNumberStart:NSTextField?
	@IBOutlet weak var pageNumberStart:NSTextField?
	
	@IBOutlet weak var printSections:NSButton?
	@IBOutlet weak var printSynopsis:NSButton?
	@IBOutlet weak var printNotes:NSButton?
	
	@IBOutlet weak var pageNumberingModeDefault:NSButton?
	@IBOutlet weak var pageNumberingModeScene:NSButton?
	@IBOutlet weak var pageNumberingModePageBreak:NSButton?
		
	@IBOutlet weak var novelSettings:NSView?
	@IBOutlet weak var lineHeight:NSSegmentedControl?
	@IBOutlet weak var contentAlignment:NSSegmentedControl?
	
	@objc weak var editorDelegate:BeatEditorDelegate?
	var pageNumberingMode:BeatPageNumberingMode = .default
	
	override var windowNibName: String! {
		return "BeatDocumentSettingWindow"
	}
	
	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		refresh()
	}
	
	@objc func refresh() {
		guard let delegate = editorDelegate, let appDelegate = NSApplication.shared.delegate as? BeatAppDelegate, let styleMenu = self.styleMenu else { return }

		// Style menu
		appDelegate.styleMenuManager.setupMenuItems(for: styleMenu.menu!)
		for item in styleMenu.menu?.items ?? [] {
			if let styleItem = item as? BeatMenuItemWithStylesheet {
				if delegate.styles.name == styleItem.stylesheet {
					styleMenu.selectItem(withTitle: styleItem.title)
					break
				}
			}
		}
		
		// Shared settings
		pageSize?.selectItem(at: delegate.pageSize.rawValue)
		
		let sceneNumber = max(delegate.documentSettings.getInt(DocSettingSceneNumberStart), 1)
		sceneNumberStart?.stringValue = String(sceneNumber)
		
		let pageNumber = max(delegate.documentSettings.getInt(DocSettingFirstPageNumber), 1)
		pageNumberStart?.stringValue = String(pageNumber)
		
		printSections?.state = (delegate.documentSettings.getBool(DocSettingPrintSections)) ? .on : .off
		printSynopsis?.state = (delegate.documentSettings.getBool(DocSettingPrintSynopsis)) ? .on : .off
		printNotes?.state = (delegate.documentSettings.getBool(DocSettingPrintNotes)) ? .on : .off
		
		let paginationMode = (delegate.styles.document.paginationMode > 0) ? delegate.styles.document.paginationMode : delegate.documentSettings.getInt(DocSettingPageNumberingMode)
		if paginationMode == 1 { pageNumberingModeScene?.state = .on }
		else if paginationMode == 2 { pageNumberingModePageBreak?.state = .on }
		
		// With enforced pagination style these settings won't be available
		pageNumberingModeDefault?.isEnabled = (delegate.styles.document.paginationMode == -1)
		pageNumberingModeScene?.isEnabled = (delegate.styles.document.paginationMode == -1)
		pageNumberingModePageBreak?.isEnabled = (delegate.styles.document.paginationMode == -1)
				
		// Novel Mode settings
		novelSettings?.isHidden = delegate.styles.name != "Novel"
			
		let lh = Int(floor(delegate.documentSettings.getFloat(DocSettingNovelLineHeightMultiplier)))
		lineHeight?.selectSegment(withTag: lh)
		
		let alignment = delegate.documentSettings.getString(DocSettingContentAlignment)
		if alignment == "justify" { contentAlignment?.selectSegment(withTag: 1) }
	}
	
	@IBAction func apply(_ sender:Any?) {
		if let delegate = editorDelegate {
			
			// First check if stylesheet has changed
			let originalStylesheet = delegate.styles.name
			if let item = styleMenu?.selectedItem as? BeatMenuItemWithStylesheet, let style = item.stylesheet, originalStylesheet != style {
				delegate.setStylesheetAndReformat(style)
			}
			
			if let sceneNumber = Int(sceneNumberStart?.stringValue ?? "1") {
				if sceneNumber == 1 || sceneNumber < 0 {
					delegate.documentSettings.remove(DocSettingSceneNumberStart)
				} else {
					delegate.documentSettings.set(DocSettingSceneNumberStart, as: sceneNumber)
				}
			}
			if let pageNumber = Int(pageNumberStart?.stringValue ?? "1") {
				if pageNumber == 1 || pageNumber < 0 {
					delegate.documentSettings.remove(DocSettingFirstPageNumber)
				} else {
					delegate.documentSettings.set(DocSettingFirstPageNumber, as: pageNumber)
				}
			}
			
			delegate.documentSettings.set(DocSettingPrintSections, as: printSections?.state == .on)
			delegate.documentSettings.set(DocSettingPrintSynopsis, as: printSynopsis?.state == .on)
			delegate.documentSettings.set(DocSettingPrintNotes, as: printNotes?.state == .on)
			
			if pageNumberingModeDefault?.state == .on { delegate.documentSettings.remove(DocSettingPageNumberingMode) }
			else if pageNumberingModeScene?.state == .on { delegate.documentSettings.set(DocSettingPageNumberingMode, as: 1)}
			else if pageNumberingModePageBreak?.state == .on { delegate.documentSettings.set(DocSettingPageNumberingMode, as: 2)}
						
			delegate.pageSize = BeatPaperSize(rawValue: pageSize?.indexOfSelectedItem ?? 0) ?? .A4
			
			if lineHeight?.selectedSegment == 0 { delegate.documentSettings.remove(DocSettingNovelLineHeightMultiplier) }
			else if lineHeight?.selectedSegment == 1 { delegate.documentSettings.set(DocSettingNovelLineHeightMultiplier, as: 1.5) }
			
			let originalAlignment = delegate.documentSettings.getString(DocSettingContentAlignment)

			if contentAlignment?.selectedSegment == 0 { delegate.documentSettings.remove(DocSettingContentAlignment) }
			else { delegate.documentSettings.set(DocSettingContentAlignment, as: "justify") }
			if (originalAlignment != (delegate.documentSettings.getString(DocSettingContentAlignment))) {
				delegate.reloadStyles()
				delegate.formatting.formatAllAsynchronously()
			}
			
			// Apply changes to outline, pagination, layout and undo state
			delegate.parser.updateOutline()
			delegate.ensureLayout()
			delegate.updateChangeCount(.changeDone)
			delegate.resetPreview()
		}
		
		if let window {
			window.sheetParent?.endSheet(window)
		}
	}
	
	@IBAction func togglePaginationMode(_ sender:NSButton) {
		if let mode = BeatPageNumberingMode(rawValue: sender.tag) {
			pageNumberingMode = mode
		}
	}
		
	@IBAction func cancel(_ sender:Any?) {
		if let window {
			window.sheetParent?.endSheet(window)
		}
	}
		
	override func cancelOperation(_ sender: Any?) {
		if let window {
			window.sheetParent?.endSheet(window)
		}
	}
}
