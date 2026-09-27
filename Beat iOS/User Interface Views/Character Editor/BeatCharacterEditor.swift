//
//  BeatCharacterEditor.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 26.9.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

/*
import UIKit
import SwiftUI
import BeatCore

class BeatCharacterEditor: UIViewController {

	var delegate:BeatEditorDelegate
	
	init(delegate: BeatEditorDelegate) {
		self.delegate = delegate
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		// let backups = BeatBackup.backups(name: delegate.fileNameString()).sorted { $0.date > $1.date }
		// init the view ...
		

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
}
*/
