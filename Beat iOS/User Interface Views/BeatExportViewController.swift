//
//  BeatExportViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 24.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import SwiftUI
import PDFKit
import BeatCore


/// Export setting table view controller
final class BeatExportSettingController:UITableViewController, BeatPDFControllerDelegate {
	@IBOutlet @objc weak var temporaryView:UIView?
	@IBOutlet @objc weak var activityIndicator:UIActivityIndicatorView?
	
	// MARK: PDF view
	@IBOutlet var previewView:PDFView?
	var pdfController:BeatPDFController?
	
	// MARK: Setting switches etc.
	@IBOutlet var revisionSwitches:[BeatCheckboxButton]?
	@IBOutlet var paperSize:UISegmentedControl?
	@IBOutlet var printSceneNumbers:UISwitch?
	
	@IBOutlet var sceneHeadingBolded:UISwitch?
	@IBOutlet var sceneHeadingUnderlined:UISwitch?
	@IBOutlet var sceneHeadingSpacing:UISegmentedControl?
	
	@IBOutlet var printNotes:UISwitch?
	@IBOutlet var printSections:UISwitch?
	@IBOutlet var printSynopsis:UISwitch?
	
	@IBOutlet var header:UITextField?
	
	@objc weak var editorDelegate:BeatEditorDelegate?
	
	var hiddenRevisions:[Int] {
		guard let revisionSwitches = self.revisionSwitches else { return [] }
		var hiddenRevisions:[Int] = []
		
		for revision in revisionSwitches {
			if !revision.isChecked {
				//hiddenRevisions.insert(revision.tag)
				hiddenRevisions.append(revision.tag)
			}
		}
		
		return hiddenRevisions
	}
	
	override func viewWillAppear(_ animated: Bool) {
		guard let editorDelegate = self.editorDelegate else { return }
		self.activityIndicator?.startAnimating()
		
		pdfController = BeatPDFController(delegate: self, temporaryView: self.temporaryView)
		
		printSceneNumbers?.setOn(editorDelegate.printSceneNumbers, animated: false)
		paperSize?.selectedSegmentIndex = editorDelegate.pageSize.rawValue
		
		sceneHeadingBolded?.setOn(BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleBold), animated: false)
		sceneHeadingUnderlined?.setOn(BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleUnderlined), animated: false)
		
		let spacing = BeatUserDefaults.shared().getInteger(BeatSettingSceneHeadingSpacing)
		sceneHeadingSpacing?.selectedSegmentIndex = (spacing == 2) ? 0 : 1
		
		printNotes?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintNotes), animated: false)
		printSections?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintSections), animated: false)
		printSynopsis?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintSynopsis), animated: false)
		
		header?.text = self.editorDelegate?.documentSettings.getString(DocSettingHeader) ?? ""
				
		refreshPreview()
		
		// Toggle revisions
		let hiddenRevisions = editorDelegate.documentSettings.get(DocSettingHiddenRevisions) as? [Int] ?? []
		print("Hidden revisions:", hiddenRevisions)
		for revision in revisionSwitches ?? [] {
			revision.isChecked = !hiddenRevisions.contains(revision.tag)
		}
		
		// This is a remnant from the time when I planned on making the iOS version paywalled. I'm keeping it here to remind me that it was a bad idea.
		//checkPaywall()
	}
	
	@IBAction func close(_ sender:Any?) {
		self.navigationController?.popViewController(animated: true)

	}
	
	// MARK: Toggle settings
	
	@IBAction func togglePaperSize(_ sender:Any?) {
		refreshDocument()
	}
	
	@IBAction func toggleSetting(sender:BeatUserSettingSwitch?) {
		guard let button = sender,
			  let key = sender?.setting
		else { return }
		
		if button.documentSetting {
			// Save to document settings
			editorDelegate?.documentSettings.setBool(key, as: button.isOn)
		} else {
			// Save to user defaults
			BeatUserDefaults.shared().save(button.isOn, forKey: key)
		}
		
		refreshDocument()
	}
	
	@IBAction func toggleSpacing(sender:UISegmentedControl?) {
		guard let control = sender else { return }
		
		let spacing = (control.selectedSegmentIndex == 0) ? 2 : 1
		
		BeatUserDefaults.shared().save(spacing, forKey: BeatSettingSceneHeadingSpacing)
	}
	
	@IBAction func toggleRevision(sender:UIButton?) {
		self.editorDelegate?.documentSettings.set(DocSettingHiddenRevisions, as: self.hiddenRevisions)
		refreshPreview()
	}
	
	/// Refresh the underlying document
	func refreshDocument() {
		DispatchQueue.main.async { [weak self] in
			self?.editorDelegate?.reloadStyles()
			self?.refreshPreview()
		}
	}
	
	/// Refresh preview
	var timer:Timer?
	var firstPreview = true
	func refreshPreview() {
		// Clear the preview
		self.previewView?.document = nil
		self.activityIndicator?.startAnimating()
				
		let bounds = self.previewView?.bounds ?? CGRect.zero
		
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { [weak self] _ in
			DispatchQueue.main.async {
				self?.pdfController?.createPDF(completion: { url in
					if let url = url, let pdf = PDFDocument(url: url), let previewView = self?.previewView {
						previewView.document = pdf
						previewView.bounds = bounds

						previewView.scaleFactor = 0.6
//						if (self?.firstPreview ?? false) { previewView.scaleFactor = previewView.scaleFactorForSizeToFit - 0.3 }
//						else { previewView.scaleFactor = scale }
						
						self?.activityIndicator?.stopAnimating()
					}
				})
			}
		})
	}
	
	@IBAction func editHeader(_ sender:UITextField?) {
		self.editorDelegate?.documentSettings.set(DocSettingHeader, as: sender?.text ?? "")
	}
	
	
	// MARK: - Export button
	
	@IBAction func savePDF(_ sender:Any?) {
		self.pdfController?.createPDF(completion: { url in
			guard let url = url else {
				self.close(sender)
				return
			}
			
			let shareController = BeatShareSheetController(items: [url], excludedTypes: [.assignToContact, .addToReadingList, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToFlickr, .postToTencentWeibo])
			
			self.present(shareController, animated: true) {
				self.close(nil)
			}
		})
	}
	
	
	// MARK: - Export settings
	
	func exportSettings() -> BeatExportSettings {
		guard let settings = editorDelegate?.exportSettings else {
			print("ERROR: No export settings found")
			return BeatExportSettings()
		}
		
		// Then, let's adjust them according to export panel
		settings.paperSize = BeatPaperSize(rawValue: self.paperSize?.selectedSegmentIndex ?? 0) ?? .A4
		settings.printSceneNumbers = printSceneNumbers?.isOn ?? true
		
		var additionalTypes = IndexSet()
		
		if printSections?.isOn ?? false { additionalTypes.insert(Int(LineType.section.rawValue)) }
		if printSynopsis?.isOn ?? false { additionalTypes.insert(Int(LineType.synopse.rawValue)) }
		settings.additionalTypes = additionalTypes
		
		var revisions:IndexSet = IndexSet(integersIn: 0..<BeatRevisions.revisionGenerations().count)
		
		for rev in hiddenRevisions {
			revisions.remove(rev)
		}
		
		return settings
	}
	
	// MARK: - Paywall
	// This was an idiotic
	/*
	
	func checkPaywall() {
		Task {
			let unlocked = await BeatSubscriptionsManager.shared.unlocked()
			if !unlocked {
				showPaywall()
			}
		}
	}
	
	var paywallVC:BeatPaywallViewController?
	func showPaywall() {
		let vc = BeatPaywallViewController(rootView: BeatPaywallView(dismissAction: {
			self.paywallVC?.dismiss(animated: true)
		})) {
			Task {
				let unlocked = await BeatSubscriptionsManager.shared.unlocked()
				if !unlocked {
					self.close(nil)
				}
			}
		}
		
		vc.modalPresentationStyle = .formSheet
		self.paywallVC = vc
		
		self.present(vc, animated: true)
	}
	*/
}


