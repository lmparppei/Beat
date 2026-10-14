//
//  BeatDocumentViewController+Layout.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 4.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

extension BeatDocumentViewController {
	open override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		guard let scrollView, let pageView, pageView.frame.width > 0 else { return }
		
		let actualPageWidth = (pageView.frame.width / scrollView.zoomScale) + 10.0
		var newZoomScale = size.width / actualPageWidth
		
		newZoomScale = min(max(newZoomScale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
		
		coordinator.animate(alongsideTransition: { _ in
			scrollView.setZoomScale(newZoomScale, animated: false)
			scrollView.layoutIfNeeded()
		}) { _ in
			if let textView = self.textView as? BeatUITextView {
				textView.updateZoomScale(scrollView: scrollView, animated: false)
			}
		}
	}
}
