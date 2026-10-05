//
//  BeatDocumentViewController+Loading.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 4.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

fileprivate var loadingOverlay:LoadingOverlayView?
extension BeatDocumentViewController {
	
	@objc func showLoadingBar() {
		guard isViewLoaded, loadingOverlay == nil else { return }
		let overlay = LoadingOverlayView()   // dimmed background + UIProgressView / UIActivityIndicatorView
		overlay.frame = view.bounds
		overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(overlay)
		loadingOverlay = overlay
	}
	
	@objc func hideLoadingBar() {
		guard let overlay = loadingOverlay else { return }
		UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in
			overlay.removeFromSuperview()
		}
		loadingOverlay = nil
	}
	
}
