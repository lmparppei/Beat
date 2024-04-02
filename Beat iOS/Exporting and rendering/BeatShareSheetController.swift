//
//  BeatShareSheetController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 26.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatShareSheetController: UIViewController {
	private let activityController: UIActivityViewController

	init(items: [Any], excludedTypes:[UIActivity.ActivityType] = []) {
		self.activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
		self.activityController.excludedActivityTypes = excludedTypes
		
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .formSheet
	}

	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
	
		addChild(activityController)
		view.addSubview(activityController.view)
		
		activityController.view.translatesAutoresizingMaskIntoConstraints = false
	
		NSLayoutConstraint.activate([
			activityController.view.topAnchor.constraint(equalTo: view.topAnchor),
			activityController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			activityController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			activityController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
	}
}
