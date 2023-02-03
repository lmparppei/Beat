//
//  BeatiOSOutlineView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatiOSOutlineView: UITableView, UITableViewDelegate, UITableViewDataSource {
	@IBOutlet weak var editorDelegate:BeatEditorDelegate!
	
	let cellIdentifier = "OutlineCell"
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
		
		self.delegate = self
		self.dataSource = self
		
		self.backgroundColor = UIColor.black;
		self.backgroundView?.backgroundColor = UIColor.black;
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if (editorDelegate.parser == nil) { return 0 }
		editorDelegate.parser.createOutline()
		print("count ", editorDelegate.parser.outline.count)
		return editorDelegate.parser.outline.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = self.dequeueReusableCell(withIdentifier: cellIdentifier)! as UITableViewCell
		cell.backgroundView?.backgroundColor = UIColor.black
		cell.backgroundColor = UIColor.black
		
		let scene = self.editorDelegate.parser.outline[indexPath.row] as! OutlineScene
		
		let string = OutlineViewItem.withScene(scene, currentScene: editorDelegate.currentScene, withSynopsis: true, isDark: true)
		cell.textLabel?.attributedText = string
		
		return cell
	}
}
/*
class BeatiOSOutlineCell: UITableViewCell {
	@IBOutlet var label:UILabel?
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
}
 */
