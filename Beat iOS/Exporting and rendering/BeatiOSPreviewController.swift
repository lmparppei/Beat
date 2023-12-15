//
//  BeatiOSPreviewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 15.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatPagination2

class BeatPreviewController:BeatPreviewManager, WKScriptMessageHandler {
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if message.name == "selectSceneFromScript" {
			print(" -> select scene", message.body)
		}
		else if message.name == "closePrintPreview" {
			// Dismiss preview view
			print(" -> dismiss preview view")
			previewView?.dismissPreviewView(sender: nil)
		}
	}
	
	
	var renderer:BeatHTMLRenderer?
	var htmlString = ""
	@objc weak var previewView:BeatPreviewView?
	
	func setup() {
		previewView?.webview?.configuration.userContentController.add(self, name: "selectSceneFromScript")
		previewView?.webview?.configuration.userContentController.add(self, name: "closePrintPreview")
		
		previewView?.webview?.pageZoom = 1.2
		
		loadPlaceHolder()
	}
	
	deinit {
		previewView?.webview?.configuration.userContentController.removeAllScriptMessageHandlers()
		previewView?.webview?.navigationDelegate = nil
		previewView?.webview = nil
	}
	
	override func resetPreview() {
		super.resetPreview()
	}
	
	func loadPlaceHolder() {
		previewView?.webview?.loadHTMLString("<html><body style='background-color: #333; margin: 0;'><section style='margin: 0; padding: 0; width: 100%; height: 100vh; display: flex; justify-content: center; align-items: center; font-weight: 200; font-family: \"Helvetica Light\", Helvetica; font-size: .8em; color: #eee;'>Creating Print Preview...</section></body></html>", baseURL: nil)
	}
	
	func renderPreview() -> String? {
		guard let pagination = self.pagination?.finishedPagination else { return "" }
		
		self.renderer = BeatHTMLRenderer(pagination: pagination, settings: self.settings)
		settings.operation = .ForPreview
		
		return renderer?.html()
	}
	
	override func paginationDidFinish(_ operation: BeatPagination) {
		super.paginationDidFinish(operation)
		
		renderOnScreen()
	}
	
	@objc override func renderOnScreen() {
		guard let html = renderPreview() else {
			loadPlaceHolder()
			return
		}
		
		// Code injection to scroll to current line
		let line = self.delegate?.parser.closestPrintableLine(for: self.delegate?.currentLine())
		let uuid = line?.uuidString().lowercased() ?? ""
		
		let scrollScriptTemplate = "<script name='scrolling'></script>"
		let scrollToScript = "<script>scrollToIdentifier('" + uuid + "');</script>"
		
		DispatchQueue.main.async {
			self.htmlString = html.replacingOccurrences(of: scrollScriptTemplate, with: scrollToScript)
			
			self.previewView?.webview?.loadHTMLString(self.htmlString, baseURL: Bundle.main.resourceURL)
			
			// Revert changes to the code (so we can replace the placeholder again when needed, without recreating the whole HTML)
			self.htmlString = self.htmlString.replacingOccurrences(of: scrollToScript, with: scrollScriptTemplate)
			
			// Make sure we've scrolled to the correct scene
			self.previewView?.webview?.evaluateJavaScript("scrollToIdentifier('" + uuid + "');")
		}
	}
	
}
