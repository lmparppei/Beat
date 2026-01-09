//
//  BeatTagReportView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.6.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//


fileprivate enum TagReportType:Int {
	case sceneVsTags = 0
	case tagVsScene = 1
	case screenplayWithTags = 2
}

class BeatTagReportView:NSViewController, BeatTagManagerView, NSOutlineViewDelegate, NSOutlineViewDataSource {
	weak var delegate:BeatEditorDelegate?
	@IBOutlet weak var typeList:NSOutlineView?
	@IBOutlet weak var selectAllCheckbox:NSButton?
	@IBOutlet weak var textView:NSTextView?
	@IBOutlet weak var warningLabel:NSTextField?
		
	var checked:[BeatTagType] = []
	private var reportType:TagReportType = .sceneVsTags
	
	var awoken = false
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		if !awoken {
			typeList?.dataSource = self
			typeList?.delegate = self
			
			self.typeList?.reloadData()
			awoken = true
		}
	}
		
	func reload() {
		self.typeList?.reloadData()
	}
	
	@IBAction func toggleReportType(_ sender:NSButton?) {
		if let sender {
			self.reportType = TagReportType(rawValue: sender.tag) ?? .sceneVsTags
		}
	}
	
	@IBAction func checkItem(_ sender:NSButton?) {
		guard let type = BeatTagType(rawValue: sender?.tag ?? -1), let checkbox = sender else { return }
		
		if checkbox.state == .on, !checked.contains(type) {
			checked.append(type)
		} else {
			checked.removeObject(object: type)
		}
		
		updateSelectAll()
	}
	
	@IBAction func selectAllTags(_ sender: NSButton) {
		if sender.state == .on || sender.state.rawValue == -1 {
			checked = BeatTagging.tagKeys().keys.map({ BeatTagType(rawValue: $0.intValue) ?? .NoTag })
		} else {
			checked = []
		}
		
		reload()
		updateSelectAll()
	}
	
	func updateSelectAll() {
		if checked.count == BeatTagging.tagKeys().count {
			selectAllCheckbox?.state = .on
		} else if checked.count > 0 {
			selectAllCheckbox?.state = .mixed
		} else {
			selectAllCheckbox?.state = .off
		}
	}
	
	// MARK: - Data source and delegate
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		return (item == nil) ? BeatTagging.categories().count : 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return BeatTagging.categories()[index]
	}

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CategoryCell"), owner: self) as? BeatTagCategoryCheckboxCell
		
		if let tagName = item as? String {
			view?.textField?.stringValue = BeatTagging.localizedTagName(forKey: tagName)
						
			let type = BeatTagging.tag(for: tagName)
			let color = BeatTagging.color(for: type)
			
			let image = BeatTagManager.tagIcon(type: type)
			view?.imageView?.image = image
			if #available(macOS 10.14, *) {
				view?.imageView?.contentTintColor = color
			}
			
			view?.checkbox?.tag = type.rawValue
			view?.checkbox?.state = checked.contains(type) ? .on : .off
		}
		
		return view
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		return false
	}
	
	
	// MARK: - Buttons
	var printView:RTFPrintView?
	@IBAction func createPDF(_ sender:Any?) {
		guard checked.count > 0 else {
			warningLabel?.stringValue = BeatLocalization.localizedString(forKey: "tagManager.list.warning.noTypes")
			return
		}
		warningLabel?.stringValue = ""
		
		self.delegate?.tagging.bakeTags()
		var string:NSAttributedString? = nil

		if reportType == .screenplayWithTags {
			self.createScreenplayAndClose()
			return
		} else if reportType == .tagVsScene {
			string = self.delegate?.tagging.reportByType(checked)
		} else if reportType == .sceneVsTags {
			string = self.delegate?.tagging.reportByScene(self.checked)
		}
		
		if let string {
			printView = RTFPrintView(text: string)
			printView?.pdf()
		}
	}
	
	func createScreenplayAndClose() {
		if let lines = self.delegate?.tagging.screenplayWithScenesWithTagTypes(self.checked) {
			
			var text = ""
			for line in lines {
				var str = line.string ?? ""
				if line.type == .heading, line.sceneNumberRange.length == 0, let sceneNumber = line.sceneNumber {
					str = str.trimmingCharacters(in: .whitespaces) + " #\(sceneNumber)#"
				}
				text += str + "\n"
			}

			let appDelegate = NSApplication.shared.delegate as? BeatAppDelegate
			appDelegate?.newDocument(withContents: text)
		}
		
		self.view.window?.windowController?.close()
	}
}

class BeatTagCategoryCheckboxCell:NSTableCellView {
	@IBOutlet var checkbox:NSButton?
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	@IBAction func check(_ sender:Any?) {
	}
}
