//
//  SceneDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 25.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let _ = scene as? UIWindowScene else { return }

	   window?.makeKeyAndVisible()
		
		// UIKit handles storyboard loading automatically
		// Only handle URL if the app was cold-launched via one
		if let url = connectionOptions.urlContexts.first?.url {
			print("Configure with URL")
			configure(window: window, with: url)
		} else if let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
			print("Configure with activity")
			configure(window: window, with: activity)
		}
	}
	
	func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		configure(window: window, with: userActivity)
	}
			
	func sceneDidBecomeActive(_ scene: UIScene) { }

	func sceneWillResignActive(_ scene: UIScene) { }

	func sceneDidEnterBackground(_ scene: UIScene) {
		//
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		// Undo changes made on entering background
	}
	
	func sceneDidDisconnect(_ scene: UIScene) {
		guard let session = (scene as? UIWindowScene)?.session else { return }
		let documents = BeatDocumentManager.shared.documentControllers
		if let doc = documents.first(where: { $0.sessionIdentifier == session.persistentIdentifier }) {
			BeatDocumentManager.shared.removeDocumentController(doc)
		}
	}
	
	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let inputURL = URLContexts.first?.url,
			  inputURL.isFileURL else { return }
		
		if let documentView = window?.rootViewController as? BeatDocumentViewController {
			let doc = UIDocument(fileURL: inputURL)
			documentView.document = doc
		}
	}
	
	func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
		guard let controller = BeatDocumentManager.shared.documentControllers.first(where: {
			$0.view.window?.windowScene == scene
		}), let url = controller.fileURL else {
			return nil
		}
		return DocumentActivity.make(for: url)
	}
	
	func findDocumentViewController(in root: UIViewController?) -> BeatDocumentViewController? {
		guard let root else { return nil }
		if let match = root as? BeatDocumentViewController { return match }
		for child in root.children {
			if let found = findDocumentViewController(in: child) { return found }
		}
		return nil
	}
	
	func configure(window: UIWindow?, with activity: NSUserActivity) {
		guard let url = DocumentActivity.documentURL(from: activity) else { return }
		configure(window: window, with: url)
	}
	
	func configure(window: UIWindow?, with url: URL) {
		guard let docView = findDocumentViewController(in: window?.rootViewController) else { return }
		
		//docView.loadView()
		
		
			docView.document = iOSDocument(fileURL: url)
		
	}
	
}
