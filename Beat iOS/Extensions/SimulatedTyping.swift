//
//  SimulatedTyping.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 16.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

@objc class SimulatedTyping:NSObject {
	private weak var textView: UITextView?
	private var timer: Timer?
	private let sampleText: String
	private var currentIndex = 0
	private var deleting = false
	
	private let typingIntervalRange: ClosedRange<Double> = 0.05...0.25
	private let pauseChance: Double = 0.06 // occasional thinking pauses
	private let paragraphChance: Double = 0.03 // chance to add a paragraph break
	private let maxTextLength = 800 // prevent runaway growth
	
	@objc init(textView: UITextView) {
		self.textView = textView
		
		self.sampleText = """
		Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed vitae nisl a purus tincidunt auctor. Quisque sed felis sed libero laoreet dapibus. Curabitur convallis lorem et nulla suscipit, in faucibus odio gravida. Proin nec augue nec erat ultricies porttitor. Nullam sed dictum metus. Aliquam erat volutpat. Vivamus convallis enim ut nisi suscipit, id fermentum justo facilisis. Etiam gravida mi in eros aliquam, ac vehicula justo fermentum. Suspendisse eget dolor sed lorem efficitur commodo. Donec interdum suscipit libero, nec laoreet nisl vulputate ut. Nunc viverra urna vel justo pharetra, id lacinia leo porttitor. Praesent porta quam vel lectus tempor, a tristique est commodo.
		"""
		
		super.init()
		
		start()
	}
	
	func start() {
		stop()
		scheduleNext()
	}
	
	func stop() {
		timer?.invalidate()
		timer = nil
	}
	
	private func scheduleNext() {
		let interval = Double.random(in: typingIntervalRange)
		timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
			self?.tick()
		}
	}
	
	private func tick() {
		guard let textView = textView else { return }
		
		if deleting {
			// Simulate backspacing
			if !textView.text.isEmpty {
				textView.text.removeLast()
			} else {
				deleting = false
			}
		} else {
			// Simulate typing
			if Double.random(in: 0...1) < paragraphChance {
				textView.text.append("\n\n")
			} else {
				let nextChar = sampleText[sampleText.index(sampleText.startIndex, offsetBy: currentIndex)]
				textView.text.append(nextChar)
				currentIndex = (currentIndex + 1) % sampleText.count
			}
			
			// Switch to deleting mode occasionally
			if textView.text.count > maxTextLength && Bool.random() {
				deleting = true
			}
		}
		
		// Occasional pauses
		if Double.random(in: 0...1) < pauseChance {
			timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
				self?.scheduleNext()
			}
		} else {
			scheduleNext()
		}
	}
	
	deinit {
		stop()
	}
}
