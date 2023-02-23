//
//  BeatPopover.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 17.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatPopoverContentController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	// Custom design&implementation
}

extension DocumentViewController {
	
	@IBAction func buttonClicked(_ sender: AnyObject) {
		//get the button frame
		/* 1 */
		
		let view = sender.value(forKey: "view") as! UIView
		print("frame", view.frame)
		
		var frame = view.frame
		frame.origin.x += view.superview?.frame.origin.x ?? 0
		frame.origin.y += 20
		let buttonFrame = frame
		
		
		/* 2 */
		//Configure the presentation controller
		let popoverContentController = self.storyboard?.instantiateViewController(withIdentifier: "QuickSettings") as? BeatPopoverContentController
		popoverContentController?.modalPresentationStyle = .popover

		/* 3 */
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
