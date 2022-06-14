//
//  PrintTest.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class PrintToPDF: NSObject {

	var window:NSWindow!

	var pdfURL:NSURL?
	var webview:WKWebView?

	func makeWebview(html:String) {
		webview = WKWebView()
		webview?.loadHTMLString(html, baseURL: nil)
	}

	func exportToPDF (url: NSURL) {
		let printInfo = NSPrintInfo.shared
		printInfo.dictionary().addEntries(from: [
			NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
			NSPrintInfo.AttributeKey.jobSavingURL: url
		])
		
		// Set margins
		printInfo.topMargin = 12.5
		printInfo.leftMargin = 12.5
		printInfo.rightMargin = 12.5
		printInfo.bottomMargin = 12.5

		var offset = CGSize(width: 0, height: 0)
		let referenceMargin = 12.5
		let imageableOrigin = CGSize(width: printInfo.imageablePageBounds.origin.x, height: printInfo.imageablePageBounds.origin.y)
		
		if (imageableOrigin.width - referenceMargin > 0) {
			offset.width = imageableOrigin.width - referenceMargin
		}
		if (imageableOrigin.height - referenceMargin > 0) {
			offset.height = imageableOrigin.height - referenceMargin
		}
		
		printInfo.topMargin = printInfo.topMargin - offset.height;
		printInfo.leftMargin = printInfo.topMargin - offset.width;
		
		if #available(macOS 11.0, *) {
			let printOperation = webview?.printOperation(with: printInfo)
			printOperation?.showsPrintPanel = false
			printOperation?.showsProgressPanel = true
			
			printOperation?.runModal(for: self.window, delegate: self, didRun: #selector(printOperationDidRun), contextInfo: nil)
		}
	}

	@objc func printOperationDidRun (operation:Any, success:Bool, contextInfo:Any?) {
		
	}
}
