//
//  BeatiOSOutlineView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatiOSOutlineView: UITableView, UITableViewDelegate, BeatSceneOutlineView {
	
	@IBOutlet weak var editorDelegate:BeatEditorDelegate!
	var dataProvider:BeatOutlineDataProvider?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		// Register outline view
		self.editorDelegate.register(self)
		
		self.delegate = self
		
		self.backgroundColor = UIColor.black;
		self.backgroundView?.backgroundColor = UIColor.black;
		
		self.dataProvider = BeatOutlineDataProvider(delegate: self.editorDelegate, tableView: self)
		self.dataProvider?.update()
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
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let i = indexPath.row
		guard let scene = self.editorDelegate.parser.outline[i] as? OutlineScene else { return }
		
		self.editorDelegate.selectedRange = NSMakeRange(NSMaxRange(scene.line.textRange()), 0)
		self.editorDelegate.scroll(to: scene.line)
		
		self.selectRow(at: nil, animated: true, scrollPosition: .middle)
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
