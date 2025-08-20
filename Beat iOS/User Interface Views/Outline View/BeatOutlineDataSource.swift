//
//  BeatOutlineDataSource.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 27.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore
import BeatParsing

@objc class BeatOutlineDataSource:NSObject, UITableViewDataSource {
	var delegate:BeatEditorDelegate
	
	init(delegate: BeatEditorDelegate) {
		self.delegate = delegate
		
		super.init()
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return delegate.parser.outline.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Scene") as! BeatOutlineViewCell
		let dark = UIView.shouldAppearAsDark(view: cell, apply: true)
		
		if let scene = delegate.parser.outline[indexPath.row] as? OutlineScene {
			let string = OutlineViewItem.withScene(scene,
												   currentScene: OutlineScene(),
												   sceneNumber: BeatUserDefaults().getBool(BeatSettingShowSceneNumbersInOutline),
												   synopsis: BeatUserDefaults().getBool(BeatSettingShowSynopsisInOutline),
												   notes: BeatUserDefaults().getBool(BeatSettingShowNotesInOutline),
												   markers: BeatUserDefaults().getBool(BeatSettingShowMarkersInOutline),
												   isDark: dark)
			
			cell.representedScene = scene
			cell.textLabel?.attributedText = string
		}
		
		return cell
	}
}

@objc class BeatOutlineDataProvider:NSObject, UITableViewDelegate {
	
	var dataSource:UITableViewDiffableDataSource<Int,OutlineDataItem>
	var delegate:BeatEditorDelegate
	var updating = false
	var latestSnapshot:NSDiffableDataSourceSnapshot<Int, OutlineDataItem>?
	
	weak var tableView:UITableView?
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.latestSnapshot?.numberOfItems ?? 0
	}
		
	@objc init(delegate:BeatEditorDelegate, tableView:UITableView) {
		self.delegate = delegate
		self.tableView = tableView
		
		self.dataSource = UITableViewDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, itemIdentifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Scene") as! BeatOutlineViewCell
			cell.editor = delegate
			
			let scene = delegate.parser.outline[indexPath.row] as! OutlineScene
			let string = OutlineViewItem.withScene(scene,
												   currentScene: OutlineScene(),
												   sceneNumber: BeatUserDefaults().getBool(BeatSettingShowSceneNumbersInOutline),
												   synopsis: BeatUserDefaults().getBool(BeatSettingShowSynopsisInOutline),
												   notes: BeatUserDefaults().getBool(BeatSettingShowNotesInOutline),
												   markers: BeatUserDefaults().getBool(BeatSettingShowMarkersInOutline),
												   isDark: true)
			
			cell.representedScene = scene
			cell.textLabel?.attributedText = string
			
			return cell
		})
		super.init()
		
		// Create initial snapshot
		if let snapshot = self.initialSnapshot() {
			self.latestSnapshot = snapshot
			self.dataSource.apply(snapshot, animatingDifferences: true)
		}
	}
	
	@objc func update() {
		guard let outline = delegate.parser.outline as? [OutlineScene] else {
			print("ERROR: Failed to create outline")
			return
		}
		
		let items:[OutlineDataItem] = outline.map { OutlineDataItem(with: $0) }
		
		print(" • Snapshot items:", items.count, "previously", self.dataSource.snapshot().numberOfItems)
		
		var snapshot = NSDiffableDataSourceSnapshot<Int, OutlineDataItem>()
		snapshot.appendSections([0])
		snapshot.appendItems(items)
		
		updating = true
		self.latestSnapshot = snapshot
		
		self.dataSource.apply(snapshot, animatingDifferences: false) {
			self.updating = false
		}
	}
	
	func initialSnapshot() -> NSDiffableDataSourceSnapshot<Int, OutlineDataItem>? {
		guard let outline = delegate.parser.outline as? [OutlineScene] else { return nil }
		
		var items:[OutlineDataItem] = []
		for scene in outline {
			let item = OutlineDataItem(with: scene)
			items.append(item)
		}
		
		var snapshot = NSDiffableDataSourceSnapshot<Int, OutlineDataItem>()
		snapshot.appendSections([0])
		snapshot.appendItems(items)
		
		return snapshot
	}
	
}

class OutlineDataItem:Hashable {
	var string:String
	var color:String
	var synopsis:[Line]
	var beats:[Storybeat]
	var markers:[[String:String]]
	var sceneNumber:String
	var uuid:UUID
	var range:NSRange
	var selected:Bool
	weak var scene:OutlineScene?
	
	init(with scene:OutlineScene) {
		self.string = scene.string
		self.color = scene.color
		self.synopsis = scene.synopsis as? [Line] ?? []
		self.beats = scene.beats as? [Storybeat] ?? []
		self.markers = scene.markers as? [[String : String]] ?? []
		self.sceneNumber = scene.sceneNumber ?? ""
		self.uuid = scene.line.uuid ?? UUID()
		self.range = scene.range()
		self.selected = false
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(uuid)
		hasher.combine(string)
		hasher.combine(color)
		hasher.combine(markers)
	}

	static func == (lhs: OutlineDataItem, rhs: OutlineDataItem) -> Bool {
		return lhs.uuid == rhs.uuid
	}
}
