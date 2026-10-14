//
//  BeatUITextView+ScrollViewDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 6.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

extension BeatUITextView:UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return pageView
	}
		
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		//
	}
	
	func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		updateZoomScale(scrollView: scrollView)
	}
	
	func updateZoomScale(scrollView:UIScrollView, animated:Bool = true) {
		guard let pageView else { return }
		var x = (scrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0; }
				
		var frame = pageView.frame
		frame.origin.x = x
		
		var zoom = scrollView.zoomScale
		
		// Page view will always be at least the height of the screen
		if (frame.height < scrollView.frame.height) {
			let factor = frame.height / scrollView.frame.height
			zoom = scrollView.zoomScale / factor
		}
		
		// Set content scale factor (see UIView+Scale extension)
		// We'll multiply the value with screen native scale. Not sure if this is wise or not.
		let scale = scrollView.zoomScale * UIScreen.main.nativeScale
		
		scrollView.scaleViewTree(to: scale)
		self.scaleView(scale: scale)

		if animated {
			UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) { [weak self] in
				self?.pageView?.frame.origin.x = frame.origin.x
				
				//self?.enclosingScrollView?.zoomScale = zoom
				self?.resizeScrollViewContent()
			} completion: { _ in
				
			}
		} else {
			pageView.frame.origin.x = frame.origin.x
			enclosingScrollView?.zoomScale = zoom
			resizeScrollViewContent()
		}
	}
		
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView){
		lastOffsetY = scrollView.contentOffset.y
	}
	
	func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView){
		/*
		let hide = scrollView.contentOffset.y > self.lastOffsetY
		if let vc = self.getViewController() {
			let nc = vc.navigationController
			vc.navigationController?.setToolbarHidden(hide, animated: true)
		}
		*/
	}
}
