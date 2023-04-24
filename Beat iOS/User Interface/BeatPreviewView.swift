//
//  BeatPreviewView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import WebKit

class BeatPreviewView:UIViewController {
	
	@objc @IBOutlet weak var webview:WKWebView?
	
	@IBAction func dismissPreviewView(sender: Any?) {
		self.dismiss(animated: true)
	}
}
