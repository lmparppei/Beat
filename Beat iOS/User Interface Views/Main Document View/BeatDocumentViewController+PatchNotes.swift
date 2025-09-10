//
//  BeatDocumentViewController+PatchNotes.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 9.10.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import WebKit

@objc extension BeatDocumentViewController {
	@objc func displayPatchNotesIfNeeded() {
		guard let buildNumberStr = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
			  let buildNumber = Int(buildNumberStr)
		else { return }
		
		let lastRunVersion = UserDefaults.standard.integer(forKey: "lastRunVersion")
		
		if buildNumber > lastRunVersion && lastRunVersion > 0 {
			let viewController = PatchNotesViewController()
			self.present(viewController, animated: true)
		}
		
		UserDefaults.standard.set(buildNumber, forKey: "lastRunVersion")
	}
}

class PatchNotesViewController: UIViewController {
	private let webView: WKWebView = {
		let webView = WKWebView()
		webView.translatesAutoresizingMaskIntoConstraints = false
		return webView
	}()
		
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setupUI()
		loadPatchNotes()
	}
	
	// Set up the UI
	private func setupUI() {
		view.addSubview(webView)
		view.backgroundColor = .systemBackground
		
		let dismissButton = UIButton(type: .system)
		dismissButton.setTitle("Dismiss", for: .normal)
		dismissButton.translatesAutoresizingMaskIntoConstraints = false
		dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
		
		view.addSubview(dismissButton)
		
		NSLayoutConstraint.activate([
			webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
			webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			webView.bottomAnchor.constraint(equalTo: dismissButton.topAnchor, constant: -20)
		])
		
		NSLayoutConstraint.activate([
			dismissButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
			dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
		])
	}
	
	private func loadPatchNotes() {
		guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
			  let templateURL = Bundle.main.url(forResource: "BeatPatchNoteTemplate", withExtension: "html"),
			  let patchNotesURL = Bundle.main.url(forResource: version, withExtension: "html"),
			  let content = try? String(contentsOf: patchNotesURL),
			  var template = try? String(contentsOf: templateURL)
		else { return }
		
		template = template.replacingOccurrences(of: "{{version}}", with: version)
		template = template.replacingOccurrences(of: "{{content}}", with: content)
		webView.loadHTMLString(template, baseURL: nil)
	}
	
	@objc private func dismissTapped() {
		dismiss(animated: true, completion: nil)
	}
}
