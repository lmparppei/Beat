//
//  Document+IndexCardPrinting.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 19.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatPlugins
import JavaScriptCore

extension Document {
	@objc func printIndexCards() {
		if let d = self as? BeatPluginDelegate {
			IndexCardPrinter.print(with: d)
		}
	}
}
