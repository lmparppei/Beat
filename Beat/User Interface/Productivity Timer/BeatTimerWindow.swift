//
//  BeatTimerWindow.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 12.11.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc protocol BeatTimerWindowDelegate {
	var timer:Timer? { get set }
	var timeOriginal:CGFloat { get set }
	var timeTotal:Int { get set }
	var timeLeft:Int { get }
	
	var window:NSWindow? { get }
	
	func running() -> Bool
	func reset()
	func pause()
	func timer(for seconds:Int)
	
}

class BeatTimerWindow:NSWindowController {
	
	@objc weak var timerDelegate:BeatTimerWindowDelegate?
	
	@objc @IBOutlet weak var minutes:NSTextField?
	@IBOutlet weak var label:NSTextField?
	
	@IBOutlet weak var startButton:NSButton?
	@IBOutlet weak var resetButton:NSButton?
	@IBOutlet weak var pauseButton:NSButton?
	
	let playImg = NSImage(named: NSImage.touchBarPlayTemplateName)
	let pauseImg = NSImage(named: NSImage.touchBarPauseTemplateName)
	
	override var windowNibName: String! {
		return "BeatTimerWindow"
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	override func windowDidLoad() {
		refresh()
	}
	
	func refresh() {
		guard let timerDelegate = self.timerDelegate else {
			print("No timer delegate set")
			return
		}
		
		if timerDelegate.running() {
			self.minutes?.isEnabled = false
			
			self.startButton?.title = BeatLocalization.localizedString(forKey: "timer.reset")
			self.pauseButton?.image = pauseImg
			self.pauseButton?.isHidden = false
			
			let timeMinutes = timerDelegate.timeLeft / 60
			let timeSeconds = timerDelegate.timeLeft - timeMinutes * 60
			
			self.label?.isHidden = true

			self.minutes?.stringValue = String(timeMinutes) + ":" + String(timeSeconds)
		} else {
			self.startButton?.title =  			BeatLocalization.localizedString(forKey: "timer.start")
			pauseButton?.image = playImg
		}
	}
	
	@IBAction func setTimer(_ sender:NSButton?) {
		guard let minutes = self.minutes, let timerDelegate = self.timerDelegate else { return }
		
		if timerDelegate.timeLeft > 0 {
			// Reset
			reset()
		} else {
			// Start a new timer
			let seconds = Int(minutes.intValue * 60)
			self.timerDelegate?.timer(for: seconds)
			self.close()
		}
	}

	@IBAction func close(_ sender:NSButton?) {
		close()
	}
	
	override func close() {
		timerDelegate?.window?.endSheet(self.window!)
		super.close()
	}
	
	func reset() {
		guard let timerDelegate = self.timerDelegate else {
			print("No timer delegate")
			return
		}
		
		timerDelegate.reset()
		
		resetButton?.isHidden = true
		pauseButton?.isHidden = true
		label?.isHidden = false
		
		minutes?.isEnabled = true
		
		startButton?.title = BeatLocalization.localizedString(forKey: "timer.start")
		
		if timerDelegate.timeTotal > 0 {
			minutes?.stringValue = String(timerDelegate.timeTotal / 60)
		} else {
			minutes?.stringValue = "25"
		}
	}
	
	@IBAction func pause(_ sender:NSButton?) {
		guard let timerDelegate = self.timerDelegate else { return }
		self.timerDelegate?.pause()
		
		if timerDelegate.running() {
			pauseButton?.image = pauseImg
		} else {
			pauseButton?.image = playImg
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		close()
	}
}
