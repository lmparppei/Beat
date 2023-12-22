//
//  BeatiOSOutlineView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatiOSOutlineView: UITableView, UITableViewDelegate, BeatSceneOutlineView {
	
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	var dataProvider:BeatOutlineDataProvider?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.delegate = self
		self.backgroundColor = UIColor.black;
		self.backgroundView?.backgroundColor = UIColor.black;
		
		self.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
		self.estimatedRowHeight = 14.0
		self.rowHeight = UITableView.automaticDimension
		
		if let editorDelegate = self.editorDelegate {
			setup(editorDelegate: editorDelegate)
		}
		
		let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeToClose))
		swipe.direction = .left
		self.addGestureRecognizer(swipe)
	}
	
	func setup(editorDelegate:BeatEditorDelegate) {
		// Register outline view
		editorDelegate.register(self)
					
		self.dataProvider = BeatOutlineDataProvider(delegate: editorDelegate, tableView: self)
		self.dataProvider?.update()
		
		self.keyboardDismissMode = .onDrag
	}
		
	func reload(with changes: OutlineChanges!) {
		self.reload()
	}
	
	func reloadInBackground() {
		self.reload()
	}
	
	func reload() {
		self.dataProvider?.update()
	}
		
	func visible() -> Bool {
		if self.frame.width > 1 {
			return true
		} else {
			return false
		}
	}
	
	@objc func swipeToClose() {
		self.editorDelegate?.toggleSidebar(self)
	}
		
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		let i = indexPath.row
		if i > editorDelegate.parser.outline.count { return }
		guard let scene = editorDelegate.parser.outline[i] as? OutlineScene else { return }
		
		editorDelegate.selectedRange = NSMakeRange(NSMaxRange(scene.line.textRange()), 0)
		editorDelegate.scroll(to: scene.line)
		
		// on iPhone we'll dismiss this view right after selecting a scene
		if UIDevice.current.userInterfaceIdiom == .phone {
			editorDelegate.toggleSidebar(self)
		}
	}
		
	/// Updates current scene
	var previousLine:Line?
	var selectedItem:OutlineDataItem?
	
	@objc func update() {
		guard let editorDelegate = self.editorDelegate else { return }
		
		// Do nothing if the line hasn't changed
		if editorDelegate.currentLine() == previousLine { return }
		
		// Spaghetti code follows:
		let snapshot = self.dataProvider!.dataSource.snapshot()

		let oldSelectedItem = selectedItem
		self.selectedItem = nil
		
		for i in 0..<snapshot.numberOfItems {
			// Because items are only created for visible items, we need to scroll to selected item using the snapshot data source
			let item = snapshot.itemIdentifiers(inSection: 0)[i]
			if NSLocationInRange(editorDelegate.selectedRange.location, item.range) {
				selectedItem = item
				if (oldSelectedItem != item) {
					scrollToSelectedItem()
				}
			}
			
			// Then update the selected status for each visible item
			if let c = self.cellForRow(at: IndexPath(row: i, section: 0)) {
				let selected = selectedItem == item
				c.setSelected(selected, animated: true)
			}
		}
	}
	
	func scrollToSelectedItem() {
		guard let selectedItem = selectedItem,
			  let dataSource = self.dataProvider?.dataSource,
			  let indexPath = dataSource.indexPath(for: selectedItem) else {
			return
		}

		// Scroll to the selected item's row.
		if self.numberOfRows(inSection: indexPath.section) > 0 {
			do {
				try scrollToRow(at: indexPath, at: .middle, animated: true)
			} catch {
				print("Error scrolling to row", error)
			}
		}
	}
}

class BeatOutlineViewCell:UITableViewCell {
	@IBOutlet var textField:UILabel?
	weak var representedScene:OutlineScene?
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.backgroundColor = .black
		setup()
	}
	
	func setup() {
		self.backgroundColor = .black

		let selectionView = UIView()
		selectionView.backgroundColor = ThemeManager.shared().outlineHighlight
		self.selectedBackgroundView = selectionView

	}
}
