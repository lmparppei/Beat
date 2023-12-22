//
//  BeatQuickSettings.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatDocumentViewController:UIPopoverPresentationControllerDelegate {
	@IBAction func openSettings(_ sender:AnyObject) {
		if let vc = self.storyboard?.instantiateViewController(withIdentifier: "Settings") as? BeatSettingsViewController {
			vc.modalPresentationStyle = .formSheet
			vc.delegate = self
			self.present(vc, animated: true)
		}
	}
	
	@IBAction func openQuickSettings(_ sender: AnyObject) {
		var frame = CGRectZero
		var buttonFrame = CGRectZero
		
		if let view = sender.value(forKey: "view") as? UIView {
			frame = view.frame
			frame.origin.x += view.superview?.frame.origin.x ?? 0
			frame.origin.y += 20
			buttonFrame = frame
		}
		
		//Configure the presentation controller
		let popoverContentController = self.storyboard?.instantiateViewController(withIdentifier: "QuickSettings") as? BeatSettingsViewController
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

class BeatSettingsViewController:UITableViewController {
	@objc weak var delegate:BeatEditorDelegate?
	
	// Local document settings
	@IBOutlet var revisionGeneration:UISegmentedControl?
	@IBOutlet var revisionMode:UISwitch?
	@IBOutlet var pageSizeSwitch:UISegmentedControl?
	@IBOutlet var headingSpacingSwitch:UISegmentedControl?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView.delegate = self
		
		guard let delegate = self.delegate else { return }
		
		self.revisionMode?.setOn(delegate.revisionMode, animated: false)
		self.pageSizeSwitch?.selectedSegmentIndex = delegate.pageSize.rawValue
		
		let spacing = BeatUserDefaults.shared().getInteger(BeatSettingSceneHeadingSpacing)
		self.headingSpacingSwitch?.selectedSegmentIndex = (spacing == 2) ? 0 : 1
	}
	
	@IBAction func toggleSetting(_ sender:BeatUserSettingSwitch?) {
		guard let key = sender?.setting,
			  let button = sender
		else { return }
		
		if !button.documentSetting {
			BeatUserDefaults.shared().save(button.isOn, forKey: key)
		} else {
			delegate?.documentSettings.setBool(key, as: button.isOn)
		}
		
		if button.redrawTextView {
			delegate?.getTextView().setNeedsDisplay()
		}
		
		if button.reformatHeadings {
			delegate?.formatting.formatAllLines(of: .heading)
		}
		
		if button.resetPreview {
			delegate?.invalidatePreview()
		}
		
		if button.reloadOutline {
			// ?
		}
	}
	
	@IBAction func togglePageSize(_ sender:UISegmentedControl) {
		/// OK lol, this is a silly thing to do, but `BeatPageSize` is an enum (`0` is A4 and `1` is US Letter) so why not.
		delegate?.pageSize = BeatPaperSize(rawValue: sender.selectedSegmentIndex) ?? .A4
	}
	
	@IBAction func selectRevisionGeneration(_ sender:UISegmentedControl) {
		let generations = BeatRevisions.revisionGenerations()
		let gen = generations[sender.selectedSegmentIndex]
		
		delegate?.revisionColor = gen.color
	}
	
	@IBAction func toggleHeadingSpacing(_ sender:UISegmentedControl) {
		let value = (sender.selectedSegmentIndex == 0) ? 2 : 1
		BeatUserDefaults.shared().save(value, forKey: BeatSettingSceneHeadingSpacing)
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		// Hide certain cells
		if let cell = self.tableView(tableView, cellForRowAt: indexPath) as? BeatAdaptiveCellView {
			if cell.hiddenOnMobile && UIDevice.current.userInterfaceIdiom == .phone { return 0.0 }
		}
		return super.tableView(tableView, heightForRowAt: indexPath)
	}
	
	@IBAction func visitSite(_ sender:BeatURLButton?) {
		if let url = URL(string: sender?.url ?? "") {
			UIApplication.shared.open(url)
		}
	}
}

class BeatURLButton:UIButton {
	@IBInspectable var url:String?
}
