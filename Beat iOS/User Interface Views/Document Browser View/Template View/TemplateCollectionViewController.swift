//
//  TemplateCollectionViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 19.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class TemplateCollectionViewController: UIViewController, UICollectionViewDelegateFlowLayout {
	var didPickTemplate = false
	@objc public var importHandler: ((URL?, UIDocumentBrowserViewController.ImportMode) -> Void)?
	@objc var errorMessage:String?
	
	@IBOutlet weak var collectionView: UICollectionView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.overrideUserInterfaceStyle = .dark
	}

	func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		guard let cell = collectionView.cellForItem(at: indexPath) as? BeatTemplateCell else {
			return false
		}
		
		var url = cell.url
		var targetUrl:URL?
		var filename = url?.lastPathComponent
		
		// Because the templates are in another bundle, we'll need to copy it first
		if let productName = cell.product {
			filename = productName
		}
		
		if let originalUrl = url, filename != nil {
			targetUrl = URL(filePath: NSTemporaryDirectory()).appending(component: filename!)
			
			// Copy the template file to temp directory
			do {
				try FileManager.default.copyItem(at: originalUrl, to: targetUrl!)
			} catch {
				errorMessage = "Couldn't copy the template"
			}
		}
		
		if targetUrl != nil {
			// Copy the file and open it
			self.importHandler?(targetUrl, .copy)
			didPickTemplate = true
		} else {
			errorMessage = "No template URL"
		}
		
		if (self.errorMessage != nil) {
			let alert = UIAlertController(title: "Error loading template", message: "Take a screenshot of this message and send it to the developer:\n\(self.errorMessage ?? "")", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			self.parent?.present(alert, animated: true)
			print(self.errorMessage ?? "(error)")
		}
		
		// Dismiss the template controller
		self.dismiss(animated: true) {
			
		}

		return true
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		var height = 140.0
		if UIDevice.current.userInterfaceIdiom == .phone {
			height = 100.0
		}
		
		return CGSize(width: collectionView.frame.size.width, height: height)
	}

	override func viewWillDisappear(_ animated: Bool) {
		// If we didn't pick a template, the import handler still has to be called
		if !didPickTemplate {
			self.importHandler?(nil, .none)
		}
	}
}
