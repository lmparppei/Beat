//
//  LoadingOverlayView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 4.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

final class LoadingOverlayView: UIView {

	private let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
	private let spinner = UIActivityIndicatorView(style: .large)

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		// Dim the content underneath and swallow touches while loading
		backgroundColor = UIColor.black.withAlphaComponent(0.25)
		isUserInteractionEnabled = true

		container.translatesAutoresizingMaskIntoConstraints = false
		container.layer.cornerRadius = 16
		container.layer.cornerCurve = .continuous
		container.clipsToBounds = true
		addSubview(container)

		spinner.translatesAutoresizingMaskIntoConstraints = false
		spinner.hidesWhenStopped = false
		container.contentView.addSubview(spinner)

		NSLayoutConstraint.activate([
			// Centered in the overlay, whatever its size
			container.centerXAnchor.constraint(equalTo: centerXAnchor),
			container.centerYAnchor.constraint(equalTo: centerYAnchor),
			container.widthAnchor.constraint(equalToConstant: 88),
			container.heightAnchor.constraint(equalToConstant: 88),

			spinner.centerXAnchor.constraint(equalTo: container.contentView.centerXAnchor),
			spinner.centerYAnchor.constraint(equalTo: container.contentView.centerYAnchor)
		])

		isAccessibilityElement = true
		accessibilityLabel = NSLocalizedString("Loading", comment: "Loading overlay")
		accessibilityTraits = .updatesFrequently
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		// Restart the animation whenever the view (re)enters a window
		if window != nil {
			spinner.startAnimating()
		} else {
			spinner.stopAnimating()
		}
	}
}
