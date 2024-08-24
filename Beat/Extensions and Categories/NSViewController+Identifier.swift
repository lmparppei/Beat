//
//  NSViewController+Identifier.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.8.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

extension NSViewController {
	var storyboardId: String {
		return value(forKey: "storyboardIdentifier") as? String ?? "none"
	}
}
