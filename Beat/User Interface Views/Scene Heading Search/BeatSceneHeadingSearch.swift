//
//  BeatSceneHeadingSearch.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.9.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class is a mess but it works. It's also very late, so I don't care.
 
 */

import Cocoa

struct BeatSceneHeadingSearchResult {
	var page = 0
	var scene:OutlineScene? = nil
}

class BeatSceneHeadingSearch:NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate
 {
	@objc weak var delegate:BeatEditorDelegate?
	@IBOutlet weak var textField:NSTextField?
	@IBOutlet weak var tableView:NSTableView?
	
	var results:[BeatSceneHeadingSearchResult] = []
	
	override var windowNibName: String! {
		return "BeatSceneHeadingSearch"
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.window?.isReleasedWhenClosed = true
		
		textField?.delegate = self
		delegate?.parser.updateOutline() // create a new outline from scratch, just in case
		//results = delegate?.parser.outline as! [OutlineScene]
		results = []
		self.filter("")
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		guard let textField = self.textField, let tableView = self.tableView else { addCloseOnOutsideClick(); return; }
		addCloseOnOutsideClick(ignoring: [textField, tableView])
	}

	
	deinit {
		removeCloseOnOutsideClick()
	}
	
	override func cancelOperation(_ sender: Any?) {
		// Esc pressed
		self.closeModal()
	}
	
	
	func controlTextDidChange(_ obj: Notification) {
		filter(textField?.stringValue ?? "")
	}
	
	func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		// Don't perform up and down commands
		return commandSelector == #selector(moveUp(_:)) || commandSelector == #selector(moveDown(_:))
	}
	
	
	override func keyUp(with event: NSEvent) {
		if event.keyCode == 53 {
			// Close on esc
			self.closeModal()
			return
		} else if event.keyCode == 36 {
			// Select on enter
			selectScene()
		} else if event.keyCode == 126 {
			// up
			if tableView!.numberOfRows > 0 {
				var selected = tableView!.selectedRow - 1;
				if (selected < 0) { selected = tableView!.numberOfRows - 1; }
				tableView?.selectRowIndexes([selected], byExtendingSelection: false)
				tableView?.scrollRowToVisible(tableView!.selectedRow)
				return
			}
		} else if event.keyCode == 125 {
			// down
			if tableView!.numberOfRows > 0 {
				var selected = tableView!.selectedRow + 1;
				if (selected >= tableView!.numberOfRows) { selected = 0; }
				tableView?.selectRowIndexes([selected], byExtendingSelection: false)
				tableView?.scrollRowToVisible(tableView!.selectedRow)
				return
			}
		}
				
		super.keyUp(with: event)
	}
	
	func closeModal() {
		removeCloseOnOutsideClick()
		
		guard let window = self.window,
			  let documentWindow = self.delegate?.documentWindow
		else {
			return
		}
				
		documentWindow.endSheet(window)
		
		self.tableView?.removeFromSuperview()
		self.textField?.removeFromSuperview()
		
		self.textField = nil
		self.tableView = nil
		self.window = nil
		self.results = []
	}
	
	// MARK: - Filtering and jumping to scene
	
	func selectScene() {
		guard let delegate,
			  let tableView,
			  tableView.selectedRow >= 0,
			  tableView.selectedRow != NSNotFound,
			  let dataSource = tableView.dataSource,
			  let result = dataSource.tableView?(tableView, objectValueFor: nil, row: tableView.selectedRow) as? BeatSceneHeadingSearchResult
		else {
			closeModal()
			return
		}
					
		if result.page > 0 {
			// Go to page
			let index = delegate.pagination().indexInEditor(pageNumber: result.page)
			if index != NSNotFound {
				let line = delegate.parser.line(at: index)
				delegate.scroll(to: line)
			}
		} else if let scene = result.scene {
			// Go to scene
			delegate.scroll(to: scene.line)
		}
		
		closeModal()
	}
	
	func getHeadings() -> [BeatSceneHeadingSearchResult] {
		guard let delegate, let outline = delegate.parser.outline as? [OutlineScene] else { return [] }
	
		var results:[BeatSceneHeadingSearchResult] = []
		
		for scene in outline {
			results.append(BeatSceneHeadingSearchResult(scene: scene))
		}
		
		return results
	}
	
	func filter(_ string:String) {
		guard let delegate else { return }
		
		if (string.count == 0) {
			results = getHeadings()
		} else {
			results = []
		}

		let searchString = string.uppercased()
		
		// Check if this could be a page number. We won't show all pages, just the one with this exact number.
		let pageNumber = Int(string) ?? 0
		let pages = self.delegate?.pagination().finishedPagination?.pages.count ?? 0
		if pageNumber > 0 && pageNumber <= pages {
			results.insert(BeatSceneHeadingSearchResult(page: pageNumber), at: 0)
		}
		
		for item in delegate.parser.outline {
			let scene = item as! OutlineScene
			
			let sceneNumber = (scene.sceneNumber ?? "").uppercased()
			let sceneTitle = scene.string.uppercased()
						
			if sceneTitle.contains(searchString) || sceneNumber.contains(searchString) {
				results.append(BeatSceneHeadingSearchResult(scene: scene))
			}
		}
		
		tableView?.reloadData()
		if (tableView!.numberOfRows > 0) {
			tableView?.selectRowIndexes([0], byExtendingSelection: false)
		}
	}
	
	// MARK: - Table view data source and delegate
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return results.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if (item != nil) {
			return 0
		} else {
			return results.count
		}
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return results[row]
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let result = results[row]
		let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SceneView"), owner: self) as! BeatSceneHeadingView
		
		if result.page > 0 {
			// If this is a page result, let's show it first. We only show a single page, btw.
			view.textField?.stringValue =  BeatLocalization.localizedString(forKey: "textView.information.page") + " \(result.page)"
			view.textField?.font = view.textField?.font?.bold()
			view.sceneNumber?.stringValue = ""
		} else if let scene = result.scene  {
			// This is a scene heading result
			view.textField?.stringValue = scene.stringForDisplay()
			view.sceneNumber?.stringValue = scene.sceneNumber ?? ""
		}
		
		return view
	}
	
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		self.tableView?.selectRowIndexes([row], byExtendingSelection: false)
		selectScene()
		return true
	}
	
	// MARK: - Observe clicks outside the modal
	private var monitor: Any?
	func addCloseOnOutsideClick(ignoring ignoringViews: [NSView]? = nil) {
		monitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.leftMouseDown) { [weak self] (event) -> NSEvent? in
			guard let self = self,
				  let contentView = self.window?.contentView
			else {
				return event
			}
			
			if !contentView.frame.contains(event.locationInWindow) {
				self.closeModal()
			}
			
			return event
		}
	}
	
	func removeCloseOnOutsideClick() {
	   if monitor != nil {
		   NSEvent.removeMonitor(monitor!)
		   monitor = nil
	   }
   }
}

class BeatSceneHeadingView:NSTableCellView {
	@IBOutlet weak var sceneNumber:NSTextField?
}

class BeatSceneHeadingTextField:NSTextField {
	override func cancelOperation(_ sender: Any?) {
		self.window?.windowController?.cancelOperation(sender)
	}
}
