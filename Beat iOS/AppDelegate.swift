//
//  AppDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

enum BeatForcedAppearance {
	case none
	case light
	case dark
}

@main
class BeatiOSAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		print("Beat for iOS")
		print("Documents URL", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? "(none)")
		return true
	}

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
		
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func application(_ app: UIApplication, open inputURL: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Ensure the URL is a file URL
        guard inputURL.isFileURL else { return false }
                
        // Reveal / import the document at the URL
        guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController else { return false }

        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in
            if let error = error {
                // Handle the error appropriately
                print("Failed to reveal the document at URL \(inputURL) with error: '\(error)'")
                return
            }
            
            // Present the Document View Controller for the revealed URL
            documentBrowserViewController.presentDocument(at: revealedDocumentURL!)
        }

        return true
    }
	
	/*
	func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
		guard userActivity.activityType == "fi.KAPITAN.Beat.editing",
			  let path = userActivity.userInfo?["url"] as? String
		else { return false }
		
		let url = URL(filePath: path)
		openDocument(url)
		
		return false
	}
	 */

	
	// MARK: - Dark mode stuff

	var darkMode = false
	var forcedAppearance:BeatForcedAppearance = .none
	
	@objc func checkDarkMode() {
		self.darkMode = BeatUserDefaults.shared().getBool(BeatSettingDarkMode)
		
		if UITraitCollection.current.userInterfaceStyle == .dark, !darkMode {
			forcedAppearance = .light
		} else if UITraitCollection.current.userInterfaceStyle == .light, darkMode {
			forcedAppearance = .dark
		} else {
			forcedAppearance = .none
		}
	}
	
	@objc func isDark() -> Bool {
		checkDarkMode()
		
		let systemAppearance = UITraitCollection.current.userInterfaceStyle
		
		if forcedAppearance == .none {
			return systemAppearance == .dark
		} else if forcedAppearance == .light, systemAppearance == .dark {
			return false
		} else if forcedAppearance == .dark, systemAppearance == .light {
			return true
		}
		
		return false
	}
	
	@objc func toggleDarkMode() {
		darkMode = !darkMode
		
		let systemAppearance = UITraitCollection.current.userInterfaceStyle
		
		if systemAppearance == .dark {
			forcedAppearance = (!darkMode) ? .light : .none
		}
		else {
			forcedAppearance = (darkMode) ? .dark : .none
		}
		
		BeatUserDefaults.shared().save(darkMode, forKey: BeatSettingDarkMode)
		
		NotificationCenter.default.post(name: NSNotification.Name("Appearance changed"), object: nil)
	}
}
	 

