//
//  DocumentBrowserViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers
import BeatCore
import BeatFileExport

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    var welcomeScreenShown = false
	
	override init(forOpening contentTypes: [UTType]?) {
		super.init(forOpening: contentTypes)
	}
	
	let allowedExtensions:[String] = ["fountain", "fdx", "txt", "fadein"]
	
	required init?(coder: NSCoder) {
		var contentTypes:[UTType]? = []
		
		if let fountainUTI = UTType(filenameExtension: "fountain") { contentTypes?.append(fountainUTI) }
		if let fountainData = UTType(filenameExtension: "fountain", conformingTo: UTType.data) { contentTypes?.append(fountainData) }
		if let fountain2 = UTType("fi.kapitan.fountain") { contentTypes?.append(fountain2) }
		
		// Let's manually add some extensions to help using cloud services
		for ext in allowedExtensions {
			if let uti = UTType(filenameExtension: ext) {
				contentTypes?.append(uti)
			}
		}
		
		// The user can toggle all file types on. This is required when using Google Drive.
		if BeatUserDefaults.shared().getBool(BeatSettingAllowAllFileTypes) {
			contentTypes?.append(UTType.data)
		}
		
		
		if contentTypes?.count == 0 {
			contentTypes = nil
		}
		
		super.init(forOpening: contentTypes)
	}
	
    override func viewDidLoad() {
		FileManager.default.url(forUbiquityContainerIdentifier: nil) // This can help reset state
		
        super.viewDidLoad()
        		
        delegate = self
        
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
		
		if (!welcomeScreenShown) {
			showWelcomeScreen()
		}
    }
	
	func showWelcomeScreen() {
		// If the welcome screen is suppressed, don't show it
		if (BeatUserDefaults.shared().isSuppressed("welcomeScreen")) {
			return
		}
		
		let storyBoard = UIStoryboard(name: "Main", bundle: nil)
		
		if let vc = storyBoard.instantiateViewController(withIdentifier: "Beta") as? BeatStartupScreenViewController {
			vc.modalPresentationStyle = .automatic
			vc.documentBrowser = self
			
			self.present(vc, animated: true)
		}

		welcomeScreenShown = true
	}
    
	/// Force template menu
	func pickTemplate(importHandler: ((URL?, UIDocumentBrowserViewController.ImportMode) -> Void)? = nil) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let templateVC = storyboard.instantiateViewController(identifier: "TemplateCollectionViewController") as TemplateCollectionViewController
		templateVC.importHandler = importHandler
		
		// If no import handler is provided, replace it with a generic one
		if importHandler == nil {
			templateVC.importHandler = { url, mode in
				guard let url else { return }
				self.importAndPresentTemplate(url)
			}
		}
		
		present(templateVC, animated: true)
	}
	
	func importAndPresentTemplate(_ url:URL) {
		importDocument(at: url, nextToDocumentAt: URL.documentsDirectory, mode: .copy) { url, error in
			if let url {
				self.presentDocument(at: url)
			}
		}
	}
	
	/// Forces the creation of a new document. Assumes that BeatCore has a file called `New Document.fountain`.
	public func newDocument() {
		// TODO: This name should come from a string catalogue.
		guard let url = Bundle(for: BeatTemplates.self).url(forResource: "New Document", withExtension: "fountain") else {
			print("No template for new document")
			return
		}
		
		importAndPresentTemplate(url)
	}
    
	
    
	// MARK: - UIDocumentBrowserViewControllerDelegate
    
    @objc func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let templateVC = storyboard.instantiateViewController(identifier: "TemplateCollectionViewController") as TemplateCollectionViewController
		templateVC.importHandler = importHandler
		
		present(templateVC, animated: true)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
		
		let ext = sourceURL.pathExtension.lowercased()
		if !allowedExtensions.contains(ext) {
			self.displayError(title: "Wrong File Type", message: "Files with type .\(ext) can't be opened. You might allowed all files to be displayed, so double-check you are trying to open a Fountain file.", preferredStyle: .alert)
			return
		}
				
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
		let alert = UIAlertController(title: "Error Opening Document", message: "Something went wrong when opening the file.\n\(error.debugDescription.description)" , preferredStyle: .alert)
		
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in alert.dismiss(animated: true) }))

		self.present(alert, animated: true)
    }
    	
    // MARK: - Document Presentation
    
    func presentDocument(at documentURL: URL) {
		// If this is not a Fountain file, we'll use file import
		if documentURL.pathExtension != "txt" && documentURL.pathExtension != "fountain" &&
			(documentURL.typeIdentifier != "com.kapitan.fi" && documentURL.typeIdentifier != "io.fountain") {
			importFile(at: documentURL)
			return
		}
		
		presentFountain(at: documentURL)
    }
	
	var importManager:BeatFileImportManager?
	func importFile(at documentURL:URL) {
		let alert = UIAlertController(title: "Import File", message: "You are importing a non-Fountain screenplay. A new, converted file will be created alongside the original document, which will remain untouched.\n\nDo you want to continue?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
			self.importManager = BeatFileImportManager()
			
			self.importManager?.importDocument(at: documentURL) { url in
				guard let url else {
					self.importError()
					return
				}
				
				//if url.startAccessingSecurityScopedResource() {
					self.importDocument(at: url, nextToDocumentAt: documentURL, mode: .copy) { url, error in
						if let url {
							self.presentDocument(at: url)
							//documentURL.stopAccessingSecurityScopedResource()
						}
					}
				//}
			}
		}))
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		self.present(alert, animated: true)
	}
	
	public func restoreBackup(of fileURL:URL, at backupURL:URL) {
		importDocument(at: backupURL, nextToDocumentAt: fileURL, mode: .copy) { url, error in
			if url != nil {
				self.presentDocument(at: url!)
			}
			if error != nil {
				self.displayError(title: "Backup Restoration Error", message: "Something went wrong when restoring the backup. If the current iTry moving the original file on your local device.", preferredStyle: .alert)
			}
		}
	}
	
	func displayError(title:String, message:String, preferredStyle:UIAlertController.Style) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		self.present(alert, animated: true)
	}
	
	func importError() {
		displayError(title: "Import Error", message: "Something went wrong when importing the file. This can happen with documents in iCloud, so first try moving the file to your local device.\n\nIf the problem persists, contact the developer at beat@beat-app.fi.", preferredStyle: .alert)
	}
	
	func presentFountain(at documentURL:URL) {
		let storyboard = UIStoryboard(name: "Document", bundle: nil)
		let documentViewController = storyboard.instantiateViewController(withIdentifier: "DocumentViewController") as! BeatDocumentViewController
		
		documentViewController.document = iOSDocument(fileURL: documentURL)
		documentViewController.documentBrowser = self
		
		documentViewController.loadDocument {
			let navigationController = UINavigationController(rootViewController: documentViewController)
			navigationController.modalPresentationStyle = .fullScreen
			self.present(navigationController, animated: true, completion: nil)
		}
	}	
}

