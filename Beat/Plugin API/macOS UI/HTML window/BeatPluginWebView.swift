//
//  BeatPluginWebView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/**
 This class allows plugin window HTML views to be accessed with a single click.
 */

import AppKit
import WebKit

class BeatPluginWebView:WKWebView {
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
		let window = self.window as? BeatPluginHTMLWindow ?? nil
		
		// If the window is floating (meaning it belongs to the currently active document)
		// we'll return true, otherwise it will behave in a normal way.
		if window?.level == .floating {
			return true
		} else {
			return false
		}
	}	
}
