//
//  BeatNotepadViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

class BeatNotepadViewController:UIViewController {
	
	@IBOutlet weak var notepad:BeatNotepadView?
	@IBOutlet weak var paletteButton:UIBarButtonItem?
	@objc public weak var delegate:BeatEditorDelegate?
	
	override func viewWillAppear(_ animated: Bool) {
		notepad?.editorDelegate = delegate
		notepad?.setup()
		
		if let notepad, notepad.attributedString.string.count == 0 {
			notepad.becomeFirstResponder()
		}
		
		let colorNames = ["default", "red", "green", "blue", "pink", "brown", "cyan", "orange", "magenta"]
		
		paletteButton?.menu = UIMenu(children: [
			UIDeferredMenuElement.uncached { [weak self] completion in
				var items:[UIMenuElement] = []
				
				for colorName in colorNames {
					var localized = NSLocalizedString("color."+colorName, comment: colorName)
					let image = BeatColors.labelImage(forColor: colorName, size: CGSizeMake(16.0, 16.0))
					
					let action = UIAction(title: localized, image: image, state: self?.notepad?.currentColorName == colorName ? .on : .off)  { item in
						self?.notepad?.selectColor(name: colorName)
					}
					
					items.append(action)
				}
				
				completion(items)
			}
		])
	}
	
	@IBAction func done(_ sender:Any?) {
		self.dismiss(animated: true)
		self.resignFirstResponder()
	}
}
