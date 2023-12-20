//
//  DocumentBrowserViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers


class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    var betaNoteShown = false
	
	override init(forOpening contentTypes: [UTType]?) {
		super.init(forOpening: contentTypes)
	}
	
	required init?(coder: NSCoder) {
		//super.init(coder: coder)
		let uti = UTType(filenameExtension: "fountain")
		let arr = (uti != nil) ? [uti!] : nil
		
		super.init(forOpening: arr)
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        		
        delegate = self
        
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        
		overrideUserInterfaceStyle = .dark
		
        // Update the style of the UIDocumentBrowserViewController
        browserUserInterfaceStyle = .dark
        view.tintColor = .white
		
		if (!betaNoteShown) {
			showBetaNote()
		}
    }
	
	func showBetaNote() {
		let storyBoard = UIStoryboard(name: "Main", bundle: nil)
		let vc = storyBoard.instantiateViewController(withIdentifier: "Beta")
		vc.modalPresentationStyle = .automatic
		self.present(vc, animated: true)
		betaNoteShown = true
	}
    
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let templateVC = storyboard.instantiateViewController(identifier: "TemplateCollectionViewController") as TemplateCollectionViewController
		templateVC.importHandler = importHandler
		
		present(templateVC, animated: true)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
		
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
		let alert = UIAlertController(title: "Error Opening Document", message: "Something went wrong when opening the file. Send a screenshot of this message to the developer:\n\(error.debugDescription)" , preferredStyle: .alert)
		self.present(alert, animated: true)
    }
    	
    // MARK: - Document Presentation
    
    func presentDocument(at documentURL: URL) {
		let storyBoard = UIStoryboard(name: "Main", bundle: nil)
		let documentViewController = storyBoard.instantiateViewController(withIdentifier: "DocumentViewController") as! BeatDocumentViewController
		
		documentViewController.document = iOSDocument(fileURL: documentURL)
		documentViewController.documentBrowser = self
		
		documentViewController.loadDocument {
			let navigationController = UINavigationController(rootViewController: documentViewController)
			navigationController.modalPresentationStyle = .fullScreen
			self.present(navigationController, animated: true, completion: nil)
		}
    }
	
	// MARK: - Beta notification
}

