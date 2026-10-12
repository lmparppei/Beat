//
//  WindowCoordinator.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

enum WindowCoordinator {
	private static let openDocumentsKey = "OpenDocumentsInSceneUserInfoKey"
	
	static func sceneAlreadyShowing(_ url: URL) -> UIWindowScene? {
		guard let controller = BeatDocumentManager.shared.documentControllers.first(where: {
			$0.document?.fileURL == url
		}) else {
			return nil
		}
		return controller.view.window?.windowScene
	}
	
	static func openOrActivate(_ url: URL) {
		if let existingScene = sceneAlreadyShowing(url) {
			UIApplication.shared.requestSceneSessionActivation(existingScene.session, userActivity: nil, options: nil, errorHandler: nil)
		} else {
			let activity = DocumentActivity.make(for: url)
			UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil, errorHandler: nil)
		}
	}
	
	
}
