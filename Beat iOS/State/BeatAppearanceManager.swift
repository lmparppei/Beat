//
//  BeatAppearanceManager.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.9.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

@objc final class BeatAppearanceManager:NSObject {
	@objc static let shared = BeatAppearanceManager()
	private let key = "ForcedAppearance"

	private(set) var forced: BeatForcedAppearance {
		get { BeatForcedAppearance(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .none }
		set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
	}

	@objc func isDark(scene: UIWindowScene) -> Bool {
		switch forced {
		case .none:  return scene.traitCollection.userInterfaceStyle == .dark
		case .light: return false
		case .dark:  return true
		}
	}

	/// Invert what's currently displayed
	@objc func toggle(in window: UIWindow) {
		guard let scene = window.windowScene else { return }
		setDarkMode(!isDark(scene: scene), in: window)
	}

	/// Set the desired appearance explicitly.  If the requested appearance already matches the OS, no override is stored.
	@objc func setDarkMode(_ dark: Bool, in window: UIWindow) {
		guard let scene = window.windowScene else { return }
		let systemIsDark = scene.traitCollection.userInterfaceStyle == .dark

		if dark == systemIsDark {
			// same as the OS, so nothing to force
			forced = .none
		} else {
			forced = dark ? .dark : .light
		}
		apply(to: window)
	}
	
	/// Call at launch and whenever the system style changes.
	@objc func systemStyleChanged(in window: UIWindow) {
		guard let scene = window.windowScene else { return }
		// If you go out of the app, iOS takes a snapshot of the app and flips the appearance. Nice.
		guard scene.activationState == .foregroundActive else { return }
		
		let system = scene.traitCollection.userInterfaceStyle

		print("System style changed", system == .dark ? "dark" : "light")
		
		// Check if OS has caught up with the forced mode. Erase the override when needed.
		if (forced == .dark && system == .dark) || (forced == .light && system == .light) {
			forced = .none
		}
		
		apply(to: window)
	}

	private func apply(to window: UIWindow) {
		switch forced {
		case .none:  window.overrideUserInterfaceStyle = .unspecified
		case .light: window.overrideUserInterfaceStyle = .light
		case .dark:  window.overrideUserInterfaceStyle = .dark
		}
		
		NotificationCenter.default.post(name: .init("Appearance changed"), object: nil)
	}
}
