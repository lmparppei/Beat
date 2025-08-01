//
//  BeatAppState.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

/// This is a miniscule singleton for getting the currently open document
@objc public class BeatAppState:NSObject {
	@objc public static let shared = BeatAppState()
	@objc public var documentController:BeatDocumentViewController?

	private override init() { }
}
