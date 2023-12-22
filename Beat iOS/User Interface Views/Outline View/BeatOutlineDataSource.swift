//
//  BeatOutlineDataSource.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 27.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore

@objc class BeatOutlineDataProvider:NSObject {
	var dataSource:UITableViewDiffableDataSource<Int,OutlineDataItem>
	var delegate:BeatEditorDelegate

	@objc init(delegate:BeatEditorDelegate, tableView:UITableView) {
		self.delegate = delegate
		self.dataSource = UITableViewDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, itemIdentifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Scene") as! BeatOutlineViewCell
			
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
		self.update()
	}
	
	@objc func update() {
		var items:[OutlineDataItem] = []
		for scene in delegate.parser.outline {
			let item = OutlineDataItem(with: scene as! OutlineScene)
			items.append(item)
		}
		
		var snapshot = NSDiffableDataSourceSnapshot<Int, OutlineDataItem>()
		snapshot.appendSections([0])
		snapshot.appendItems(items)
		
		self.dataSource.apply(snapshot, animatingDifferences: false)
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
		self.synopsis = scene.synopsis as! [Line]
		self.beats = scene.beats as! [Storybeat]
		self.markers = scene.markers as! [[String : String]]
		self.sceneNumber = scene.sceneNumber ?? ""
		self.uuid = scene.line.uuid!
		self.range = scene.range()
		self.selected = false
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(string)
		hasher.combine(color)
		hasher.combine(synopsis)
		hasher.combine(markers)
		hasher.combine(range)
	}

	static func == (lhs: OutlineDataItem, rhs: OutlineDataItem) -> Bool {
		return lhs.uuid == rhs.uuid
	}
}
