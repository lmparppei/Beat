//
//  NSView+Ancestor.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.1.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

extension NSView {
	/// Traverses the (table) view hierarchy and returns the enclosing outline view
	var ancestorOutlineView: NSOutlineView? {
		var view: NSView? = self
		while let currentView = view {
			if let outlineView = currentView as? NSOutlineView {
				return outlineView
			}
			view = currentView.superview
		}
		return nil
	}
}

