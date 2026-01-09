//
//  NSView+JSAnimator.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 2.12.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc protocol JSViewAnimatorExports: JSExport {
	var alphaValue: CGFloat { get set }
	var bounds: CGRect { get set }
}

/// A minimal animator class for supporting AppKit animations through JS
@objc class NSViewAnimatorBridge: NSObject, JSViewAnimatorExports {

	weak var view: NSView?
	
	@objc init(view: NSView) {
		self.view = view
	}

	@objc var alphaValue: CGFloat {
		get { view?.alphaValue ?? 1.0 }
		set { view?.animator().alphaValue = newValue }
	}

	@objc var bounds: CGRect {
		get { view?.bounds ?? .zero }
		set { view?.animator().bounds = newValue }
	}
}

@objc protocol JSViewAnimationExports:JSExport {
	@objc var jsAnimator: NSViewAnimatorBridge { get }
}

extension NSTextView: @retroactive JSExport {}
extension NSTextView: JSViewAnimationExports {
	@objc var jsAnimator: NSViewAnimatorBridge {
		return NSViewAnimatorBridge(view: self)
	}
}
