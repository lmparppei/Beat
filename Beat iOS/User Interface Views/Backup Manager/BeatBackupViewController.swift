//
//  BeatBackupManager.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import SwiftUI

@objc protocol BeatBackupViewControllerDelegate:BeatEditorDelegate {
	//weak var documentBrowser:UIDocumentBrowserViewController? { get }
}

class BeatBackupViewController: UIViewController {

	var delegate:BeatBackupViewControllerDelegate
	
	init(delegate: BeatBackupViewControllerDelegate) {
		self.delegate = delegate
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		let backups = BeatBackup.backups(name: delegate.fileNameString()).sorted { $0.date > $1.date }

		let backupListView = BackupListView(
			backups: backups,
			onSelect: { [weak self] file in
				self?.backupPrompt(for: file)
			},
			onDone: { [weak self] in
				self?.dismiss(animated: true)
			})

		let hostingController = UIHostingController(rootView: backupListView)
		addChild(hostingController)
		hostingController.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(hostingController.view)
		NSLayoutConstraint.activate([
			hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
			hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
		hostingController.didMove(toParent: self)
	}

	private func restoreBackup(_ backup:BeatBackupFile) {
		let backupURL = URL(fileURLWithPath: backup.path)
		
		if let delegate = self.delegate as? UIDocumentViewController, let document = delegate.document {
			Task {
				if let url = try? await delegate.launchOptions.browserViewController.importDocument(at: backupURL, nextToDocumentAt: document.fileURL, mode: .copy) {
					self.dismiss(animated: false)
					delegate.document = nil
					
					if let newURL = try? await delegate.launchOptions.browserViewController.revealDocument(at: url, importIfNeeded: true) {
						let newDoc = iOSDocument(fileURL: newURL)
						delegate.document = newDoc
					}
				}
			}
		}
	}
	
	private func backupPrompt(for backup: BeatBackupFile) {
		let alert = UIAlertController(
			title: "Restore Backup",
			message: "The restored backup will be saved next to the current file. If you encounter any issues, try moving current file on local device first.",
			preferredStyle: .alert
		)

		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Continue", style: .destructive) { _ in
			self.restoreBackup(backup)
		})

		present(alert, animated: true)
	}
}
