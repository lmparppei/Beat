//
//  BeatPageNumberView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 6.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

/// A small capsule view used to display page numbers on top of the text view
final class BeatPageNumberView: UIView {
	private let label = UILabel()
	private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

	override init(frame: CGRect) {
		super.init(frame: frame)
		blur.clipsToBounds = true
		addSubview(blur)

		label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
		label.textColor = .label
		label.textAlignment = .center
		addSubview(label)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.15
		layer.shadowRadius = 4
		layer.shadowOffset = CGSize(width: 0, height: 2)
	}

	required init?(coder: NSCoder) { fatalError() }

	func setText(_ text: String) {
		label.text = "\(text)"
	}

	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let labelSize = label.sizeThatFits(size)
		return CGSize(width: labelSize.width + 20, height: max(labelSize.height + 10, 26))
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		blur.frame = bounds
		blur.layer.cornerRadius = bounds.height / 2
		label.frame = bounds
	}
}
