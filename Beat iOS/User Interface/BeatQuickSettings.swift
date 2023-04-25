//
//  BeatQuickSettings.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatQuickSettings:BeatPopoverContentController {
	@IBOutlet var showPageNumbers:UISwitch?
	@IBOutlet var showSceneNumbers:UISwitch?
	@IBOutlet var revisionMode:UISwitch?
	@IBOutlet var pageSizeSwitch:UISegmentedControl?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		showPageNumbers?.setOn(self.delegate?.showPageNumbers ?? false, animated: false)
		showSceneNumbers?.setOn(self.delegate?.showSceneNumberLabels ?? false, animated: false)
		revisionMode?.setOn(self.delegate?.revisionMode ?? false, animated: false)
		
		pageSizeSwitch?.selectedSegmentIndex = (self.delegate?.pageSize ?? .A4 == .A4) ? 0 : 1
	}
	
	@IBAction func toggleShowPageNumbers(_ sender:UISwitch) {
		self.delegate?.showPageNumbers = sender.isOn
	}
	
	@IBAction func toggleShowSceneNumbers(_ sender:UISwitch) {
		self.delegate?.showSceneNumberLabels = sender.isOn
	}
	
	@IBAction func togglePageSize(_ sender:UISegmentedControl) {
		/// OK lol, this is a silly thing to do, but `BeatPageSize` is an enum (`0` is A4 and `1` is US Letter) so why not.
		self.delegate?.pageSize = BeatPaperSize(rawValue: sender.selectedSegmentIndex) ?? .A4
	}
	
	@IBAction func toggleRevisionMode(_ sender:UISwitch) {
		self.delegate?.revisionMode = sender.isOn
	}
}

extension BeatDocumentViewController {
	
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
	
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
	
	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		
	}
	
	func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
		return true
	}
	
}
