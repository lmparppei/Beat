//
//  BeatNumberInput.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

class BeatNumberInput:NSObject {
	class func presentNumberInputPrompt(on viewController: UIViewController, title: String, message: String?, currentvalue:String?, completion: @escaping (Int?) -> Void) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		alert.addTextField { textField in
			textField.text = currentvalue ?? "1"
			textField.keyboardType = .numberPad
			textField.placeholder = "123"
		}
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
			completion(nil)
		}))
		
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
			if let text = alert.textFields?.first?.text, let number = Int(text) {
				completion(number)
			} else {
				completion(nil)
			}
		}))
		
		viewController.present(alert, animated: true, completion: nil)
	}
}
