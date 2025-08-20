//
//  BeatThemeEditor.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

class BeatThemeEditor:UITableViewController {
	var editor:BeatEditorDelegate?
	
	@IBOutlet var buttons:[BeatColorWell]?
	
	var changesMade = false
	var typesRequiringUpdate:[String] = []
	var timer:Timer?
	
	override func awakeFromNib() {
		NotificationCenter.default.addObserver(forName: Notification.Name("Theme color changed"), object: nil, queue: nil) { notification in
			guard let well = notification.userInfo?["sender"] as? BeatColorWell else {
				print("No sender")
				return
			}
			
			if let type = well.lineType {
				self.typesRequiringUpdate.append(type)
			}
			
			self.scheduleUpdate()
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		timer?.invalidate()
		timer = nil
		
		if changesMade {
			updateColors()
		}
	}
	
	@IBAction func resetToDefault(_ sender:Any?) {
		ThemeManager.shared().resetToDefault()
		
		for button in buttons ?? [] {
			button.resetColor()
		}
		
		ThemeManager.shared().saveTheme()
		
		scheduleUpdate(time: 0.0)
	}
	
	func scheduleUpdate(time:Double = 1.0) {
		changesMade = true
		
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: time, repeats: false, block: { [weak self] _ in
			self?.updateColors()
		})
	}
	
	func updateColors() {
		guard let editor:BeatEditorDelegate = BeatAppState.shared.documentController else {
			print("No editor delegate")
			return
		}
		
		changesMade = false
		
		editor.updateThemeAndReformat(self.typesRequiringUpdate)
		self.typesRequiringUpdate = []
	}
}
