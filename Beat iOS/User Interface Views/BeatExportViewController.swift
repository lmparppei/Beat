//
//  BeatExportViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 24.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

/// Generic view controller for showing export settings
class BeatExportSettingViewController:UIViewController {
	@objc var editorDelegate:BeatEditorDelegate?
	weak var settingController:BeatExportSettingController?
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ToSettingsTable" {
			settingController = segue.destination as? BeatExportSettingController
			settingController?.editorDelegate = editorDelegate
		}
		super.prepare(for: segue, sender: sender)
	}
}

/// Print/export dialog
final class BeatExportViewController:BeatExportSettingViewController, PrintViewDelegate {
	var printViews: NSMutableArray! = NSMutableArray()
	
	@objc weak var senderButton:UIBarButtonItem?
	@objc weak var senderVC:UIViewController?
	
	@IBAction override func export(_ sender: Any?) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		let lines = editorDelegate.parser.lines as NSArray
		let settings = settingController!.exportSettings()
		
		let printView:BeatPrintView = BeatPrintView(script: lines.swiftArray(), operation: .toPDF, settings: settings, delegate: self)
		printViews.add(printView)
	}
	
	func didFinishPreview(at url: URL!) {
		print("Preview finished")
	}
	
	func didExportFile(at url: URL!) {
		let avc = UIActivityViewController(activityItems: [url!], applicationActivities: nil)
		avc.excludedActivityTypes = [.assignToContact, .addToReadingList, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToFlickr, .postToTencentWeibo]
			
		if (self.senderButton == nil) {
			avc.popoverPresentationController?.sourceView = self.view
			viewController().present(avc, animated: true)
		} else {
			// Let's show the activity controller in place of the original popover
			self.dismiss(animated: true) {
				avc.popoverPresentationController?.barButtonItem = self.senderButton
				self.senderVC?.present(avc, animated: true)
			}
		}
	}
	
	func viewController() -> UIViewController! {
		return self
	}
}

/// Export setting table view controller
final class BeatExportSettingController:UITableViewController {
	@IBOutlet var host:Any?
	
	@IBOutlet var revisionSwitches:[UISwitch]?
	@IBOutlet var paperSize:UISegmentedControl?
	@IBOutlet var printSceneNumbers:UISwitch?
	
	@IBOutlet var sceneHeadingBolded:UISwitch?
	@IBOutlet var sceneHeadingUnderlined:UISwitch?
	@IBOutlet var sceneHeadingSpacing:UISegmentedControl?
	
	@IBOutlet var printNotes:UISwitch?
	@IBOutlet var printSections:UISwitch?
	@IBOutlet var printSynopsis:UISwitch?
	
	weak var editorDelegate:BeatEditorDelegate?
	
	var hiddenRevisions:[String] {
		guard let revisionSwitches = self.revisionSwitches else { return [] }
		var hiddenRevisions:[String] = []
		
		for revision in revisionSwitches {
			if !revision.isOn {
				hiddenRevisions.append(BeatRevisions.revisionColors()[revision.tag])
			}
		}
		
		return hiddenRevisions
	}
	
	override func viewWillAppear(_ animated: Bool) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		printSceneNumbers?.setOn(editorDelegate.showSceneNumberLabels, animated: false)
		paperSize?.selectedSegmentIndex = editorDelegate.pageSize.rawValue
		
		sceneHeadingBolded?.setOn(BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleBold), animated: false)
		sceneHeadingUnderlined?.setOn(BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleUnderlined), animated: false)
		
		let spacing = BeatUserDefaults.shared().getInteger(BeatSettingSceneHeadingSpacing)
		sceneHeadingSpacing?.selectedSegmentIndex = (spacing == 2) ? 0 : 1
		
		printNotes?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintNotes), animated: false)
		printSections?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintSections), animated: false)
		printSynopsis?.setOn(editorDelegate.documentSettings.getBool(DocSettingPrintSynopsis), animated: false)
	}
	
	
	// MARK: Toggle settings
	
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
	
	@IBAction func toggleRevision(sender:UISwitch) {
		saveRevisions()
	}
	
	func saveRevisions() {
		self.editorDelegate?.documentSettings.set(DocSettingHiddenRevisions, as: self.hiddenRevisions)
	}
	
	/// Refresh the underlying document
	func refreshDocument() {
		weak var editorDelegate = editorDelegate
		Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
			editorDelegate?.refreshLayoutByExportSettings()
		}
		
	}
	
	// MARK: Export settings
	
	func exportSettings() -> BeatExportSettings {
		guard let settings = editorDelegate?.exportSettings else {
			print("ERROR: No export settings found")
			return BeatExportSettings()
		}
		
		// Then, let's adjust them according to export panel
		settings.paperSize = BeatPaperSize(rawValue: self.paperSize?.selectedSegmentIndex ?? 0) ?? .A4
		settings.printSceneNumbers = printSceneNumbers?.isOn ?? true
		
		var revisions:[String] = BeatRevisions.revisionColors()
		for rev in hiddenRevisions {
			if revisions.contains(rev) {
				revisions.removeObject(object: rev)
			}
		}
		
		return settings
	}
}



