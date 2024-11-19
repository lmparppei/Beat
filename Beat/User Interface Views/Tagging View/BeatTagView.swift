//
//  BeatTagView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.6.2024.
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

@objcMembers
class BeatTagEditor:NSViewController, BeatTagManagerView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate {
	weak var delegate:BeatEditorDelegate? {
		didSet {
			/// When delegate is set, we'll register the change listener
			delegate?.addChangeListener({ [weak self] _ in self?.reload() }, owner: self)
		}
	}
	
	weak var tagging:BeatTagging? { return delegate?.tagging }
	weak var editorView:BeatTagEditorView?
	
	var tagData:[String:[TagDefinition]] = [:]
	
	@IBOutlet weak var tagList:NSOutlineView?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		// Setup
		self.view.window?.delegate = self
		self.tagList?.dataSource = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(tagsDidChange), name: NSNotification.Name(BeatTagging.notificationName()), object: nil)
	}
	
	// Reload tags when they were modified in editor
	@objc func tagsDidChange(_ notification:NSNotification?) {
		if let doc = notification?.object as? BeatEditorDelegate, doc.uuid() == self.delegate?.uuid() {
			self.reload()
		}
	}
	
	func windowWillClose(_ notification: Notification) {
		NotificationCenter.default.removeObserver(self)
		self.delegate?.removeChangeListeners(for: self)
		
		// Sorry for this hack
		if let doc = self.delegate?.document() as? Document { doc.tagManager = nil }
	}

	func reload() {
		tagData = self.tagging?.sortedTags() ?? [:]
		
		// Remember the selection and previously open sections
		var previouslySelected = -1
		var expanded:[Int] = []
		
		if let tagList, let selected = self.tagList?.selectedRow, selected != NSNotFound {
			previouslySelected = selected
			
			for i in 0..<tagList.numberOfRows {
				let item = tagList.item(atRow: i)
				if tagList.numberOfChildren(ofItem: item) > 0, tagList.isItemExpanded(item) {
					expanded.append(i)
				}
			}
		}
		
		self.tagList?.reloadData()
		
		// Expand sections again
		for i in expanded {
			let item = tagList?.item(atRow: i)
			self.tagList?.expandItem(item)
		}
		
		// Select the previously selected item again
		if self.tagList?.numberOfRows ?? 0 > previouslySelected {
			self.tagList?.selectRowIndexes([previouslySelected], byExtendingSelection: false)
		}
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		
		if segue.identifier == "TagView", let vc = segue.destinationController as? BeatTagEditorView {
			editorView = vc
			vc.host = self
		}
	}
	
	
	// MARK: - Left-side outline data source and delegate
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		// Don't allow selecting tag types
		if outlineView.parent(forItem: item) != nil, let tag = item as? TagDefinition {
			editorView?.delegate = self.delegate
			editorView?.reload(tag: tag)
		}
		
		return true
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil { return BeatTagging.categories().count }

		if let tags = tagData[item as? String ?? ""] { return tags.count }
		else { return 0 }
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil { return BeatTagging.categories()[index] }
		
		let key = item as? String ?? ""
		if let tags = tagData[key] { return tags[index] }
		
		assertionFailure()
		return ""
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return outlineView.numberOfChildren(ofItem: item) > 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		var view:NSTableCellView?
		

		if let tagName = item as? String {
			// This is a tag name
			view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CategoryCell"), owner: self) as? NSTableCellView
			view?.textField?.stringValue = BeatTagging.localizedTagName(forKey: tagName)
			
			let type = BeatTagging.tag(for: tagName)
			let color = BeatTagging.color(for: type)
			
			let image = BeatTagManager.tagIcon(type: type)
			view?.imageView?.image = image
			if #available(macOS 10.14, *) {
				view?.imageView?.contentTintColor = color
			}
						
		} else if let tag = item as? TagDefinition {
			// It's a tag definition
			view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TagCell"), owner: self) as? NSTableCellView
			view?.textField?.stringValue = tag.name
		}
		
		return view
	}
}

/// The actual editor view for each tag
class BeatTagEditorView:NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	var delegate:BeatEditorDelegate?
	var tagging:BeatTagging? { return delegate?.tagging }
	
	@IBOutlet weak var tagName:BeatTagNameField?
	@IBOutlet weak var tagType:NSTextField?
	@IBOutlet weak var sceneList:NSOutlineView?
	@IBOutlet weak var renameButton:NSButton?
	@IBOutlet weak var deleteButton:NSButton?
	
	@IBOutlet weak var containerView:NSView?
	
	weak var host:BeatTagEditor?
	weak var tag:TagDefinition?
	var scenes:[OutlineScene] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.containerView?.isHidden = true
		self.sceneList?.delegate = self
		self.sceneList?.dataSource = self
	}
	
	func reload(tag:TagDefinition?) {
		// First reset controls
		self.tagName?.isEditable = false
		self.renameButton?.isEnabled = false
		self.deleteButton?.isEnabled = false
		
		if let tag {
			self.containerView?.isHidden = false
			
			self.tag = tag
			self.tagName?.stringValue = tag.name
			self.tagType?.attributedStringValue = BeatTagging.styledTag(for: tag.typeAsString()) ?? NSAttributedString()
			
			// You can't rename characters
			if tag.type != .CharacterTag {
				renameButton?.isEnabled = true
				deleteButton?.isEnabled = true
			}
		} else {
			// Empty
			self.containerView?.isHidden = true
		}
		
		// Gather scenes with tags
		scenes = self.tagging?.scenes(for: tag) ?? []
		
		self.sceneList?.reloadData()
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		return (item == nil) ? scenes.count : 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return self.scenes[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SceneCell"), owner: self) as? NSTableCellView
		
		if let scene = item as? OutlineScene, let delegate = self.delegate {
			let outlineItem = OutlineViewItem.withScene(scene, currentScene: delegate.currentScene ?? OutlineScene(), sceneNumber: true, synopsis: true, notes: true, markers: true, isDark: delegate.isDark())
			view?.textField?.attributedStringValue = outlineItem
		}
		
		return view
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		if let scene = item as? OutlineScene {
			delegate?.scroll(to: NSMakeRange(scene.line.position, 0), callback: {})
			//delegate?.scroll(to: scene.line)
		}
		
		return true
	}
	
	// MARK: - Actions
	
	@IBAction func rename(_ sender:Any?) {
		self.tagName?.isEditable = true
		self.tagName?.becomeFirstResponder()
	}

	/// Called on pressing enter in tag name field
	@IBAction func renameCommit(_ sender:BeatTagNameField) {
		// Something went wrong
		guard let tagName else { return }

		if tagName.stringValue.count > 0 {
			self.tag?.name = tagName.stringValue
			self.host?.reload()
		} else {
			// Empty value
			self.tagName?.stringValue = self.tagName?.originalText ?? ""
		}
		
		tagName.isEditable = false
		tagName.window?.makeFirstResponder(nil)
	}
	
}


class BeatTagNameField:NSTextField {
	var originalText = ""
	override var isEditable: Bool {
		didSet {
			if (isEditable) { originalText = self.stringValue }
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		if self.isEditable {
			self.window?.makeFirstResponder(nil)
			
			self.isEditable = false
			self.stringValue = originalText
		}
	}
	
	
}

fileprivate enum TagReportType:Int {
	case sceneVsTags = 0
	case tagVsScene = 1
	case screenplayWithTags = 2
}

class BeatTagList:NSViewController, BeatTagManagerView, NSOutlineViewDelegate, NSOutlineViewDataSource {
	weak var delegate:BeatEditorDelegate?
	@IBOutlet weak var typeList:NSOutlineView?
	@IBOutlet weak var selectAllCheckbox:NSButton?
	@IBOutlet weak var textView:NSTextView?
	@IBOutlet weak var warningLabel:NSTextField?
		
	var checked:[BeatTagType] = []
	private var reportType:TagReportType = .sceneVsTags
	
	override func awakeFromNib() {
		super.awakeFromNib()
		typeList?.dataSource = self
		typeList?.delegate = self
		
		self.typeList?.reloadData()
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
		if sender.state == .on {
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


class RTFPrintView:NSView {
	var margin = 0.0
	var textViews:[NSTextView] = []
	var pageTexts:[NSAttributedString] = []
	
	init(text:NSAttributedString) {
		let size = NSPrintInfo.shared.paperSize
		super.init(frame: CGRectMake(0.0, 0.0, size.width, size.height))
		
		// Separate attributed string
		let pages = text.string.components(separatedBy: "\u{0c}")
		var i = 0
		for page in pages {
			let attributedString = text.attributedSubstring(from: NSMakeRange(i, page.count))
			pageTexts.append(attributedString)
			
			i += page.count + ((page != pages.last) ? 1 : 0)

		}
		
	}
	
	func pdf() {
		let size = self.frame.size
		let margin = 10.0
		var pdfs:[PDFDocument] = []
		
		for pageText in pageTexts {
			let frame = CGRectMake(0, 0, size.width, size.height)
			
			let textView = NSTextView(frame: frame)
			textView.textContainerInset = CGSizeMake(margin, margin)
			textView.textStorage?.setAttributedString(pageText)
			
			// Calculate page height
			let bounds = pageText.boundingRect(with: CGSizeMake(textView.frame.width, .greatestFiniteMagnitude), options: .usesLineFragmentOrigin)
			textView.frame.size.height = max(bounds.height, size.height)
						
			textViews.append(textView)
			//self.addSubview(textView)
			let data = textView.dataWithPDF(inside: textView.bounds)
			if let doc = PDFDocument(data: data) {
				pdfs.append(doc)
			}
		}
		
		let fullPDF = PDFDocument()
		for singlePDF in pdfs {
			for i in 0..<singlePDF.pageCount {
				if let page = singlePDF.page(at: i) {
					fullPDF.insert(page, at: fullPDF.pageCount)
				}
			}
		}
		
		let operation = fullPDF.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: false)
		operation?.run()
	}
	
	override var isFlipped: Bool { return true }
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}


class BeatTagCategoryCheckboxCell:NSTableCellView {
	@IBOutlet var checkbox:NSButton?
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	@IBAction func check(_ sender:Any?) {
		print("Check?")
	}
}
