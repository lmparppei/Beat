//
//  BeatExportViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 24.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

final class BeatExportViewController:UIViewController, PrintViewDelegate {
	var printViews: NSMutableArray! = NSMutableArray()
	weak var settingController:BeatExportSettingController?
	@objc weak var senderButton:UIBarButtonItem?
	@objc weak var senderVC:UIViewController?
	@objc var editorDelegate:BeatEditorDelegate?
	
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
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ToSettingsTable" {
			settingController = segue.destination as? BeatExportSettingController
			settingController?.editorDelegate = editorDelegate
		}
		super.prepare(for: segue, sender: sender)
	}
	
}

final class BeatExportSettingController:UITableViewController {
	@IBOutlet var host:Any?
	
	@IBOutlet var revisionSwitches:[UISwitch]?
	@IBOutlet var paperSize:UISegmentedControl?
	@IBOutlet var printSceneNumbers:UISwitch?
	
	weak var editorDelegate:BeatEditorDelegate?
	
	override func viewWillAppear(_ animated: Bool) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		printSceneNumbers?.setOn(editorDelegate.showSceneNumberLabels, animated: false)
		paperSize?.selectedSegmentIndex = editorDelegate.pageSize.rawValue
	}
	
	func exportSettings() -> BeatExportSettings {
		// First, get settings from the editor
		let settings = editorDelegate!.exportSettings!
		
		// Then, let's adjust them according to export panel
		settings.paperSize = BeatPaperSize(rawValue: self.paperSize?.selectedSegmentIndex ?? 0) ?? .A4
		settings.printSceneNumbers = printSceneNumbers?.isOn ?? true
		
		var revisions:[String] = []
		
		for i in 0..<revisionSwitches!.count {
			let s = revisionSwitches![i]
			
			// Switches are tagged with their revision generation index (0 = blue, etc.)
			if s.isOn {
				revisions.append(BeatRevisions.revisionColors()[s.tag])
			}
		}
		
		return settings
	}
}
