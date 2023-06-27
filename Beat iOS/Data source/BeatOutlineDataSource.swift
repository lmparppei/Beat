//
//  BeatOutlineDataSource.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 27.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc class BeatOutlineDataSource:NSObject {
	var dataSource:UITableViewDiffableDataSource<Int,OutlineDataItem>
	var delegate:BeatEditorDelegate

	@objc init(delegate:BeatEditorDelegate, tableView:UITableView) {
		self.delegate = delegate
		self.dataSource = UITableViewDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, itemIdentifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Scene")
			return cell
		})
		super.init()
	}
	
	@objc func update() {
		var items:[OutlineDataItem] = []
		for scene in delegate.parser.outline {
			let item = OutlineDataItem(with: scene as! OutlineScene)
			items.append(item)
		}
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
	
	
	init(with scene:OutlineScene) {
		self.string = scene.string
		self.color = scene.color
		self.synopsis = scene.synopsis as! [Line]
		self.beats = scene.beats as! [Storybeat]
		self.markers = scene.markers as! [[String : String]]
		self.sceneNumber = scene.sceneNumber
		self.uuid = scene.line.uuid!
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(string)
		hasher.combine(color)
		hasher.combine(synopsis)
		hasher.combine(markers)
	}

	static func == (lhs: OutlineDataItem, rhs: OutlineDataItem) -> Bool {
		return lhs.uuid == rhs.uuid
	}
}
