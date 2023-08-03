//
//  BeatQuickSettings.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatQuickSettings:BeatPopoverContentController {
	@IBOutlet var settingController:BeatQuickSettingsTableController?
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ToSettingsTable" {
			settingController = segue.destination as? BeatQuickSettingsTableController
			settingController?.editorDelegate = self.delegate
		}
		super.prepare(for: segue, sender: sender)
	}
}

class BeatQuickSettingsTableController:UITableViewController {
	@IBOutlet var showPageNumbers:UISwitch?
	@IBOutlet var showSceneNumbers:UISwitch?
	@IBOutlet var revisionMode:UISwitch?
	@IBOutlet var highlightRevisions:UISwitch?
	@IBOutlet var pageSizeSwitch:UISegmentedControl?
	@IBOutlet var revisionGeneration:UISegmentedControl?
	
	var editorDelegate:BeatEditorDelegate?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		guard let delegate = self.editorDelegate else { return }
		
		showPageNumbers?.setOn(delegate.showPageNumbers, animated: false)
		showSceneNumbers?.setOn(delegate.showSceneNumberLabels, animated: false)
		revisionMode?.setOn(delegate.revisionMode, animated: false)
		highlightRevisions?.setOn(delegate.showRevisions, animated: false)
		
		pageSizeSwitch?.selectedSegmentIndex = delegate.pageSize.rawValue
		
		// Get revision generation. This is intended to be backwards and forwards compatible with future models.
		let currentGeneration = self.editorDelegate?.revisionColor ?? ""
		
		let generations = BeatRevisions.revisionGenerations()
		for i in 0..<generations.count {
			if generations[i].color == currentGeneration {
				revisionGeneration?.selectedSegmentIndex = i
				break
			}
		}
		
	}
	
	@IBAction func toggleShowPageNumbers(_ sender:UISwitch) {
		editorDelegate?.showPageNumbers = sender.isOn
	}
	
	@IBAction func toggleShowSceneNumbers(_ sender:UISwitch) {
		editorDelegate?.showSceneNumberLabels = sender.isOn
	}
	
	@IBAction func togglePageSize(_ sender:UISegmentedControl) {
		/// OK lol, this is a silly thing to do, but `BeatPageSize` is an enum (`0` is A4 and `1` is US Letter) so why not.
		editorDelegate?.pageSize = BeatPaperSize(rawValue: sender.selectedSegmentIndex) ?? .A4
	}
	
	@IBAction func toggleRevisionMode(_ sender:UISwitch) {
		editorDelegate?.revisionMode = sender.isOn
	}
	
	@IBAction func selectRevisionGeneration(_ sender:UISegmentedControl) {
		let generations = BeatRevisions.revisionGenerations()
		let gen = generations[sender.selectedSegmentIndex]
		
		editorDelegate?.revisionColor = gen.color
	}
	
	@IBAction func toggleHighlightRevisions(_ sender:UISwitch) {
		let val = NSNumber(booleanLiteral: (sender.isOn))
		BeatUserDefaults.shared().save(val, forKey: BeatSettingShowRevisions)
		editorDelegate?.getTextView().setNeedsDisplay()
	}
}

extension BeatDocumentViewController:UIPopoverPresentationControllerDelegate {
	@IBAction func openQuickSettings(_ sender: AnyObject) {
		let view = sender.value(forKey: "view") as! UIView
		
		var frame = view.frame
		frame.origin.x += view.superview?.frame.origin.x ?? 0
		frame.origin.y += 20
		let buttonFrame = frame
		
		//Configure the presentation controller
		let popoverContentController = self.storyboard?.instantiateViewController(withIdentifier: "QuickSettings") as? BeatPopoverContentController
		popoverContentController?.modalPresentationStyle = .popover
		popoverContentController?.delegate = self

		// Present popover
		if let popoverPresentationController = popoverContentController?.popoverPresentationController {
			popoverPresentationController.permittedArrowDirections = .up
			popoverPresentationController.sourceView = self.view
			popoverPresentationController.sourceRect = buttonFrame
			popoverPresentationController.delegate = self
			
			if let popoverController = popoverContentController {
				present(popoverController, animated: true, completion: nil)
			}
		}
	}
	
	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
	
	public func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		
	}
	
	public func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
		return true
	}
}
