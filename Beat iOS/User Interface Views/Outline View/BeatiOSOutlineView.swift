//
//
//  BeatiOSOutlineView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc class BeatiOSOutlineView: UITableView, UITableViewDelegate, BeatSceneOutlineView {
	@objc public var aboutToShow = false
	
	@IBInspectable var themePropertyForAutomaticAppearance:String = "outlineBackground"
	
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	//var dataProvider:BeatOutlineDataProvider?
	var outlineDataSource:BeatOutlineDataSource?
	
	/// This is a placeholder for diffable data source I guess
	var selectedItem:OutlineDataItem?
	
	/// Returns the currently selected scene
	var selectedScene:OutlineScene? {
		guard let i = self.indexPathForSelectedRow?.row,
			  i != NSNotFound,
			  i >= 0,
			  i < self.editorDelegate?.parser.outline.count ?? 0
		else { return nil }
		
		return self.editorDelegate?.parser.outline[i] as? OutlineScene
	}
	
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.delegate = self
		
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
	
	@objc func setupColors() {
		self.backgroundColor = ThemeManager.shared().outlineBackground;
		self.backgroundView?.backgroundColor = ThemeManager.shared().outlineBackground;
		self.superview?.backgroundColor = ThemeManager.shared().outlineBackground;
		
		for cell in self.visibleCells {
			let outlineCell = cell as? BeatOutlineViewCell
			outlineCell?.setup()
		}
	}
	
	func setup(editorDelegate:BeatEditorDelegate) {
		// Register outline view
		editorDelegate.register(self)
					
//		self.dataProvider = BeatOutlineDataProvider(delegate: editorDelegate, tableView: self)
//		self.dataProvider?.update()
//		self.delegate = self.dataProvider
		self.outlineDataSource = BeatOutlineDataSource(delegate: editorDelegate)
		self.dataSource = self.outlineDataSource
		
		self.keyboardDismissMode = .onDrag
	}
		
	@objc func reload(with changes: OutlineChanges!) {
		guard self.visible() else { return }
		/*
		if changes.added.count > 0 || changes.removed.count > 0 || changes.needsFullUpdate {
			self.reloadData()
		} else {
			var indices = IndexSet()
			for update in changes.updated {
				guard let scene = update as? OutlineScene,
					  let i = editorDelegate?.parser.outline.index(of: update),
					  i != NSNotFound
				else { continue }
				
				print(" -> update", scene.string)
				indices.insert(i)
			}
		}*/
		
		self.setContentOffset(self.contentOffset, animated: false)
		self.reload()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
	}
	
	@objc func reloadInBackground() {
		self.reload()
	}
	
	@objc public func reload() {
		guard (self.visible() || aboutToShow), self.hasUncommittedUpdates == false else { return }
		
		// Update appearance ahead of time
		_ = UIView.shouldAppearAsDark(view: self, apply: true)

		// Stop scrolling, just in case
		// self.setContentOffset(self.contentOffset, animated: false)
		
		self.reloadData()
		
		DispatchQueue.main.async {
			self.selectCurrentScene()
		}
		
		// Diffable alternative
		// self.dataProvider?.update()
		
		aboutToShow = false
	}
		
	func visible() -> Bool {
		guard let delegate = self.editorDelegate else { return false }
		return delegate.sidebarVisible()
	}
	
	@objc func swipeToClose() {
		self.editorDelegate?.toggleSidebar(self)
	}
		
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		let i = indexPath.row
		
		// Avoid any false positives
		guard i < editorDelegate.parser.outline.count,
			  i != NSNotFound,
			  let scene = editorDelegate.parser.outline[i] as? OutlineScene else { return }
		
		editorDelegate.scroll(to: scene.line)
		
		// on iPhone we'll dismiss this view right after selecting a scene
		if UIDevice.current.userInterfaceIdiom == .phone {
			editorDelegate.toggleSidebar(self)
		}
	}
	
	override func numberOfRows(inSection section: Int) -> Int {
		return self.dataSource?.tableView(self, numberOfRowsInSection: section) ?? 0
		//return self.dataProvider?.dataSource.snapshot().numberOfItems ?? 0
	}
	
	/// Called when the editor selection moved to another scene
	@objc func didMove(toSceneIndex index: Int) {
		if let scene = self.editorDelegate?.parser.outline[index] as? OutlineScene {
			self.selectScene(scene)
		}
	}
	
	@objc func update() {
		// ? 
	}
	
	/// Selects current scene on phones (is this a duplicate?)
	@objc func selectCurrentScene() {
		guard let currentScene = editorDelegate?.currentScene else { return }
		selectScene(currentScene)
		/*
		 // Diffable alternative
		let item = OutlineDataItem(with: currentScene)
		selectSceneItem(item)
		 */
		
	}
	
	func selectScene(_ scene:OutlineScene) {
		// Do nothing if we've already selected this scene or it doesn't exist.
		guard scene != self.selectedScene,
			  let i = self.editorDelegate?.parser.outline.index(of:scene),
			  i != NSNotFound
		else { return }
		
		let path = IndexPath(row: i, section: 0)
		self.selectRow(at: path, animated: true, scrollPosition: .middle)
	}
	
	/*
	// Diffable alternative
	func selectSceneItem(_ itemToSelect:OutlineDataItem) {
		// Do nothing if we've already selected this scene.
		guard self.selectedItem != itemToSelect else { return }
	
		 
		if let i = self.dataProvider?.dataSource.snapshot().itemIdentifiers.firstIndex(of: itemToSelect),
		   let item = self.dataProvider?.dataSource.snapshot().itemIdentifiers[i] {
			let path = self.dataProvider?.dataSource.indexPath(for: item)
			let localPath = self.presentationIndexPath(forDataSourceIndexPath: path)
			print(" -> sel current ", localPath)
			self.selectRow(at: localPath, animated: false, scrollPosition: .middle)
		}
		
		scrollToSelectedItem()

	}
	 */
	

	
	func scrollToSelectedItem() {
		/*
		// Diffable alternative
		guard let selectedItem = selectedItem,
			  let dataSource = self.dataProvider?.dataSource,
			  let indexPath = dataSource.indexPath(for: selectedItem) else {
			return
		}

		// Scroll to the selected item's row.
		if self.numberOfRows(inSection: indexPath.section) > 0 {
			scrollToRow(at: indexPath, at: .middle, animated: true)
		}
		 */
		
		guard let index = self.indexPathForSelectedRow else { return }
		self.scrollToRow(at: index, at: .middle, animated: true)
	}
}


// MARK: - Cell view for scenes

class BeatOutlineViewCell:UITableViewCell {
	@IBOutlet var textField:UILabel?
	weak var representedScene:OutlineScene?
	weak var editor:BeatEditorDelegate?
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	func setup() {
		self.backgroundColor = .clear
		
		let selectionView = UIView()
		selectionView.backgroundColor = ThemeManager.shared().outlineHighlight
		self.selectedBackgroundView = selectionView
	}
	
	
}
