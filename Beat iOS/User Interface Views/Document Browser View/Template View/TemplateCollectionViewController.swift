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

	fileprivate func createFileFromTemplate(_ url: URL?, _ filename: String?) {
		// Because the templates are in another bundle, we'll need to copy it first
		var targetUrl:URL?
		if let originalUrl = url, let filename {
			targetUrl = URL(filePath: NSTemporaryDirectory()).appending(component: filename)
			
			if let targetUrl {
				// First make sure there's no existing temp file with this name
				do {
					try FileManager.default.removeItem(at: targetUrl)
				} catch {
					print("Removing failed: \(error)")
				}
				
				// Copy the template file to temp directory
				do {
					try FileManager.default.copyItem(at: originalUrl, to: targetUrl)
				} catch {
					errorMessage = "Couldn't copy the template: \(error)"
				}
			}
		}
		
		if let targetUrl {
			// Copy the file to the final destination and open it
			self.importHandler?(targetUrl, .copy)
			didPickTemplate = true
		} else {
			errorMessage = "No template URL"
		}
		
		if (self.errorMessage != nil) {
			let alert = UIAlertController(title: "Error loading template", message: "Take a screenshot of this message and send it to the developer:\n\(self.errorMessage ?? "")", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			self.parent?.present(alert, animated: true)
			print(self.errorMessage ?? "(error loading template)")
		}
		
	}
	
	func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		guard let cell = collectionView.cellForItem(at: indexPath) as? BeatTemplateCell else {
			return false
		}
		
		let url = cell.url
		var filename = url?.lastPathComponent
		
		if let productName = cell.product {
			filename = productName
		}
		
		createFileFromTemplate(url, filename)

		
		// Dismiss the template controller
		self.dismiss(animated: true) {
			
		}
		return true
	}

	func setUTIExtendedAttribute(url: URL, uti: String) {
		let attrName = "com.apple.metadata:kMDItemContentType"
		let utiBStr = (uti as NSString).utf8String!
		setxattr(url.path, attrName, utiBStr, strlen(utiBStr), 0, 0)
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
