//
//  BeatStartupScreenViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 17.2.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatStartupScreenViewController: UIViewController {

	weak var documentBrowser:DocumentBrowserViewController?
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }


	@IBAction func newDocument(_ sender:Any?) {
		self.dismiss(animated: true) {
			self.documentBrowser?.newDocument()
		}
	}
	
	@IBAction func templates(_ sender:Any?) {
		self.dismiss(animated: true)
		self.documentBrowser?.pickTemplate()
	}

	@IBAction func browse(_ sender:Any?) {
		self.dismiss(animated: true)
	}
	
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
