//
//  BeatPageNumberView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 6.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

@objc final class BeatPageNumberOverlay: NSObject {

	private struct Marker {
		let y: CGFloat
		let pageNumber: String
	}

	private weak var textView: UITextView?
	private let containerView = UIView()
	private var capsules: [BeatPageNumberView] = []
	private var markers: [Marker] = []
	private var fadeOutWorkItem: DispatchWorkItem?

	private let fadeInDuration: TimeInterval = 0.15
	private let fadeOutDuration: TimeInterval = 0.35
	private let fadeOutDelay: TimeInterval = 0.5
	
	private var isVisible = false

	init?(textView: UITextView) {
		// Page numbers already fit on iPad layouts — only needed on iPhone.
		guard UIDevice.current.userInterfaceIdiom == .phone else { return nil }
		self.textView = textView
		super.init()
		setupContainer()
	}

	private func setupContainer() {
		guard let textView else { return }
		containerView.isUserInteractionEnabled = false
		containerView.alpha = 0
		containerView.clipsToBounds = true

		containerView.frame = textView.frame
	}

	/// Call whenever the page map is (re)computed, e.g. after re-pagination.
	func reloadPageMap(_ pageMap: NSMapTable<Line, NSArray>) {
		guard let textView = self.textView,
			  let lm = self.textView?.layoutManager as? BeatLayoutManager,
			  let tc = lm.textContainers.first
		else { return }
		
		var built: [Marker] = []
		let enumerator = pageMap.keyEnumerator()
		
		while let line = enumerator.nextObject() as? Line {
			guard let meta = pageMap.object(forKey: line),
				  meta.count > 1,
				  let pageNumber = meta.firstObject as? String,
				  let breakPosition = meta[1] as? UInt else { continue }
			
			let range = NSRange(location: Int(breakPosition) + line.position, length: 0)
			let cRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
			let yPos = lm.boundingRect(forGlyphRange: cRange, in: tc).origin.y
			
			built.append(Marker(y: yPos, pageNumber: "\(pageNumber)"))
		}
		markers = built.sorted { $0.y < $1.y }
	}

	/// Call from viewDidLayoutSubviews if the text view's frame can change (rotation, split view, etc).
	func layoutContainer() {
		guard let textView else { return }
		containerView.frame = textView.frame
		
		// Make sure the view is in hierarchy
		if containerView.superview == nil, textView.superview != nil {
			textView.superview?.addSubview(containerView)
		}
	}
}

// MARK: - Scroll delegate hooks

@objc extension BeatPageNumberOverlay {

	@objc func scrollViewDidScroll(_ scrollView: UIScrollView) {
		fadeIn()
		updateCapsules()
	}

	@objc func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
		if !willDecelerate { scheduleFadeOut() }
	}

	@objc func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		scheduleFadeOut()
	}

	@objc func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		scheduleFadeOut()
	}
}

// MARK: - Layout & animation

private extension BeatPageNumberOverlay {

	/// Binary-search the sorted marker array for the currently visible slice.
	private func visibleMarkerRange() -> ArraySlice<Marker> {
		guard let textView, !markers.isEmpty else { return markers[0..<0] }
		let topY = textView.contentOffset.y
		let bottomY = topY + textView.bounds.height

		var lo = 0, hi = markers.count
		while lo < hi {
			let mid = (lo + hi) / 2
			if markers[mid].y < topY { lo = mid + 1 } else { hi = mid }
		}
		let start = lo
		var end = start
		while end < markers.count && markers[end].y <= bottomY {
			end += 1
		}
		return markers[start..<end]
	}

	func updateCapsules() {
		guard let textView else { return }
		let visible = visibleMarkerRange()

		while capsules.count < visible.count {
			let capsule = BeatPageNumberView()
			containerView.addSubview(capsule)
			capsules.append(capsule)
		}
		
		if capsules.count > visible.count {
			for i in visible.count..<capsules.count {
				capsules[i].isHidden = true
			}
		}

		let insetTop = textView.textContainerInset.top
		let trailingX = containerView.bounds.width - 12

		for (i, marker) in visible.enumerated() {
			let capsule = capsules[i]
			capsule.isHidden = false
			capsule.setText(marker.pageNumber)
			let size = capsule.sizeThatFits(CGSize(width: 80, height: 28))
			let y = marker.y - textView.contentOffset.y + insetTop
			capsule.frame = CGRect(x: trailingX - size.width,
									y: y - size.height / 2,
									width: size.width,
									height: size.height)
		}
	}

	func fadeIn() {
		fadeOutWorkItem?.cancel()
		fadeOutWorkItem = nil
		guard !isVisible else { return }
		
		isVisible = true
		UIView.animate(withDuration: fadeInDuration, delay: 0,
						options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]) {
			self.containerView.alpha = 1
		}
	}

	func scheduleFadeOut() {
		fadeOutWorkItem?.cancel()
		
		let work = DispatchWorkItem { [weak self] in
			guard let self else { return }
			self.isVisible = false
			UIView.animate(withDuration: self.fadeOutDuration, delay: 0,
							options: [.beginFromCurrentState, .curveEaseIn, .allowUserInteraction]) {
				self.containerView.alpha = 0
			}
		}
		fadeOutWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDelay, execute: work)
	}
}
