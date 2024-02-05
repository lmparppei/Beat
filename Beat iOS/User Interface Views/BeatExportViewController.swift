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
final class BeatExportViewController:BeatExportSettingViewController {
	var printViews: NSMutableArray! = NSMutableArray()
	
	@objc weak var senderButton:UIBarButtonItem?
	@objc weak var senderVC:UIViewController?
	@IBOutlet @objc weak var temporaryView:UIView?
	
	@IBAction override func export(_ sender: Any?) {
		guard let editorDelegate = self.editorDelegate
		else { return }
		
		
		let printer = BeatPDFPrinter(delegate: editorDelegate, temporaryView: self.temporaryView) { data in
			if data == nil { return }
			
			let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
			
			if let pdfData = data,
			   let fileURL = url?.appendingPathComponent(editorDelegate.fileNameString(), isDirectory: false).appendingPathExtension("pdf") {
				do {
					try pdfData.write(to: fileURL)
					print("URL",fileURL)
					self.didExportFile(at: fileURL)
				} catch {
					print("Error",error)
				}	
			}
		}
		
		printViews.add(printer)
	}
		
	func didExportFile(at url: URL!) {
		guard let url = url else {
			self.dismiss(animated: true)
			return
		}
		
		let shareController = BeatShareSheetController(items: [url], excludedTypes: [.assignToContact, .addToReadingList, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToFlickr, .postToTencentWeibo])
		present(shareController, animated: true)
		
		/*
		let avc = UIActivityViewController(activityItems: [url!], applicationActivities: nil)
		avc.excludedActivityTypes = [.assignToContact, .addToReadingList, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToFlickr, .postToTencentWeibo]
			
		if (self.senderButton == nil) {
			avc.popoverPresentationController?.sourceView = self.view
			viewController().present(avc, animated: true)
		} else {
			// Let's show the activity controller in place of the original popover
			self.dismiss(animated: true) {
				avc.popoverPresentationController?.sourceView = self.view
				avc.popoverPresentationController?.barButtonItem = self.senderButton
				avc.modalPresentationStyle = .overCurrentContext
				self.senderVC?.present(avc, animated: true)
			}
		}
		 */
	}
	
	func viewController() -> UIViewController! {
		return self
	}
}

class BeatShareSheetController: UIViewController {
	private let activityController: UIActivityViewController

	init(items: [Any], excludedTypes:[UIActivity.ActivityType] = []) {
		self.activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
		self.activityController.excludedActivityTypes = excludedTypes
		
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .formSheet
	}

	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
	
		addChild(activityController)
		view.addSubview(activityController.view)
		
		activityController.view.translatesAutoresizingMaskIntoConstraints = false
	
		NSLayoutConstraint.activate([
			activityController.view.topAnchor.constraint(equalTo: view.topAnchor),
			activityController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			activityController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			activityController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
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
		DispatchQueue.main.async { [weak self] in
			self?.editorDelegate?.reloadStyles()
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
				
		var additionalTypes = IndexSet()
		
		if printSections?.isOn ?? false { additionalTypes.insert(Int(LineType.section.rawValue)) }
		if printSynopsis?.isOn ?? false { additionalTypes.insert(Int(LineType.synopse.rawValue)) }
		settings.additionalTypes = additionalTypes
		
		var revisions:[String] = BeatRevisions.revisionColors()
		for rev in hiddenRevisions {
			if revisions.contains(rev) {
				revisions.removeObject(object: rev)
			}
		}
		
		return settings
	}
}



