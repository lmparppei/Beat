//
//  BeatDocumentViewController+BrowserDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.9.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatDocumentViewController:UIDocumentBrowserViewControllerDelegate {
	public func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
		if #available(iOS 18.0, *) {
			guard let intent = controller.activeDocumentCreationIntent else { return }
			
			if intent.rawValue == "template "{
				print("Show template")
			}
			
		}
	}
}
