//
//  BeatAppState.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

@objc public class BeatDocumentManager:NSObject {
	@objc public static let shared = BeatDocumentManager()
	
	@objc public var documentControllers:[BeatDocumentViewController] = []

	@objc public func addDocumentController(_ documentController:BeatDocumentViewController) {
		if !documentControllers.contains(documentController) {
			documentControllers.append(documentController)
		}
	}
	
	@objc public func removeDocumentController(_ documentController:BeatDocumentViewController) {
		if documentControllers.contains(documentController) {
			documentControllers.removeObject(object: documentController)
		}
	}
	
	@objc public func documentAlreadyOpen(for url:URL, current:BeatDocumentViewController) -> Bool {
		documentControllers.contains(where: { $0.fileURL == url && $0 != current })
	}
	
	@objc public func showDocumentController(for url:URL) {
		guard let vc = documentControllers.first(where: { $0.fileURL == url }) else {
			return
		}
		
		WindowCoordinator.openOrActivate(url)
	}
	
	private override init() { }
}
