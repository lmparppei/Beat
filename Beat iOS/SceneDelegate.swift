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
		guard let windowScene = scene as? UIWindowScene else { return }
/*
		window = UIWindow(windowScene: windowScene)
		window?.rootViewController = UINavigationController(rootViewController: BeatDocumentViewController())
		window?.makeKeyAndVisible()
	*/
		
		// UIKit handles storyboard loading automatically
		// Only handle URL if the app was cold-launched via one
		if let url = connectionOptions.urlContexts.first?.url {
			handleURL(url)
		}
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
		// Release resources that can be recreated if scene reconnects
	}
	
	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let inputURL = URLContexts.first?.url,
			  inputURL.isFileURL else { return }
		
		if let documentView = window?.rootViewController as? BeatDocumentViewController {
			let doc = UIDocument(fileURL: inputURL)
			documentView.document = doc
		}
		
/*
 
		guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController else { return }

		documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in
			if let error = error {
				print("Failed to reveal the document at URL \(inputURL) with error: '\(error)'")
				return
			}
			documentBrowserViewController.presentDocument(at: revealedDocumentURL!)
		}
 */
	}
	
	func handleURL(_ url:URL!) {
		let doc = UIDocument(fileURL: url)
		let docView = BeatDocumentViewController()
		docView.document = doc
		
		window?.rootViewController?.present(docView, animated: true)
	}
}
