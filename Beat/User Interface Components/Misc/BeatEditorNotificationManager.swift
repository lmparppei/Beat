//
//  BeatEditorNotificationManager.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UXKit

struct BeatNotification {
	var title:String
	var image:UXImage?
	
	var view:UXView
	
	init(title: String, image: UXImage? = nil) {
		self.title = title
		self.image = image
		
		self.view = NSVisualEffectView(frame: CGRectMake(0.0, 0.0, 300.0, 12.0))
		self.view.layer?.cornerRadius = 12.0
		
		self.setup()
	}
	
	func setup() {
		let textView = UXTextView(frame: self.view.frame)
		
		textView.isEditable = false
		textView.drawsBackground = false
		textView.textColor = .white
		textView.alignment = .center
		
		textView.text = self.title
		
		self.view.addSubview(textView)
	}
}

class BeatEditorNotificationManager: NSObject {
	@IBOutlet weak var scrollView:UXScrollView?
	weak var parentView:NSView?
	var delegate:BeatEditorDelegate
	
	var notifications:[BeatNotification] = []
	
	init(delegate:BeatEditorDelegate, scrollView: NSScrollView?) {
		self.delegate = delegate
		self.scrollView = scrollView
		
		super.init()
	}
	
	func notify(title:String) {
		let notification = BeatNotification(title: title)
		
		self.parentView?.addSubview(notification.view)
	}
		
}
