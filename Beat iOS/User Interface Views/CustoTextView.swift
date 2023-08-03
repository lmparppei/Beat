import UIKit

class CustomTextView: UITextView {
	override var intrinsicContentSize: CGSize {
		let fixedWidth = bounds.width
		let newSize = sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
		
		if let scrollView = self.superview as? UIScrollView {
			scrollView.contentSize = newSize
		}
		
		return CGSize(width: fixedWidth, height: newSize.height)
	}
	override func layoutSubviews() {
		super.layoutSubviews()
		adjustContentSizeIfNeeded()
	}

	private func adjustContentSizeIfNeeded() {
		let fixedWidth = bounds.width
		let newSize = sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
		if bounds.size.height != newSize.height {
			if let scrollView = self.superview as? UIScrollView {
				scrollView.contentSize = newSize
			}
			print("bounds",bounds)
			bounds.origin.y = 0.0
			
			
			
			bounds.size.height = newSize.height
			invalidateIntrinsicContentSize()
			superview?.setNeedsLayout()
		}
	}
}
