//
//  BeatWebResources.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatWebResources:NSResponder, NSWindowDelegate {
	override init() {
		super.init()
		
		// Add this class into responder chain
		var responder:NSResponder? = NSApplication.shared
		while (responder != nil) {
			if (responder!.nextResponder == nil) { break }
			else { responder = responder!.nextResponder! }
		}
		responder!.nextResponder = self
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	var browser:BeatBrowserView {
		if self.browserView == nil {
			browserView = BeatBrowserView()
			browserView?.window?.delegate = self
		}
		
		return browserView!
	}
	
	var browserView:BeatBrowserView?

	func htmlURL(for filename:String) -> URL? {
		let url = Bundle.main.url(forResource: filename, withExtension: "html")
		return url
	}
	
	@objc @IBAction func showPatchNotes(sender: Any?) {
		guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
			return
		}
	
		//guard let url = Bundle.main.url(forResource: "Patch Notes", withExtension: "html") else { return }
		var suffix = "/?version=" + version
		#if ADHOC
			suffix += "&adhoc=1"
		#endif
		
		if let url = URL(string: "https://www.beat-app.fi/patch-notes/" + version.replacingOccurrences(of: ".", with: "-") + suffix) {
			print("Show url:", url)
			self.browser.showBrowser(url, withTitle: NSLocalizedString("app.patchNotes", comment: ""), width: 550, height: 640, onTop: true)
		}	
	}
	
	@IBAction func showManual(sender: Any?) {
		guard let url = Bundle.main.url(forResource: "beat_manual", withExtension: "html") else { return }
		self.browser.showBrowser(url, withTitle: NSLocalizedString("app.manual", comment: ""), width: 850, height: 600, onTop: false)
	}
			
	@IBAction func openURL(sender:BeatURLMenuItem?) {
		guard let url = sender?.url else { print("No URL specified in BeatURLMenuItem"); return }
		NSWorkspace.shared.open(url)
	}
	
	@IBAction func openURLwithButton(sender:BeatURLButton?) {
		guard let url = sender?.url else { print("No URL specified in BeatURLMenuItem"); return }
		NSWorkspace.shared.open(url)
	}
	
	func windowWillClose(_ notification: Notification) {
		let window = notification.object as? NSWindow
		if window == browser.window {
			browser.resetWebView()
			browserView = nil
		}
	}
}

class BeatURLMenuItem:NSMenuItem {
	@IBInspectable var website:String = ""
	var url:URL? {
		return URL(string: website)
	}
}

class BeatURLButton:NSButton {
	@IBInspectable var website:String = ""
	var url:URL? {
		return URL(string: website)
	}
}

