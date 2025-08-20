//
//  DiffViewerTextView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore
import AppKit

// MARK: - Supporting Classes

class DiffViewerTextView: NSTextView {
	weak var editor: BeatEditorDelegate?
	var magnification = 1.3
	var scaled = false
	
	override var frame: NSRect {
		didSet {
			updateTextLayout()
		}
	}
	
	func setup(editorDelegate: BeatEditorDelegate) {
		editor = editorDelegate
		
		textContainer?.widthTracksTextView = false
		textContainer?.lineFragmentPadding = BeatTextView.linePadding()
		
		updateTextLayout()
		
		if !scaled {
			scaleUnitSquare(to: CGSize(width: magnification, height: magnification))
			scaled = true
		}
	}
	
	private func updateTextLayout() {
		guard let editor = editor else { return }
		
		let scrollWidth = enclosingScrollView?.frame.size.width ?? 0.0
		let documentWidth = editor.documentWidth
		
		let insetWidth = (scrollWidth / 2 - documentWidth * magnification / 2) / magnification
		
		textContainerInset = CGSize(width: insetWidth, height: 10.0)
		textContainer?.containerSize = CGSize(width: documentWidth, height: .greatestFiniteMagnitude)
	}
}
