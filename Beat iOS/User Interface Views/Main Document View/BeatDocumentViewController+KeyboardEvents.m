//
//  BeatDocumentViewController+KeyboardEvents.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.1.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentViewController+KeyboardEvents.h"
#import "Beat-Swift.h"

@implementation BeatDocumentViewController (KeyboardEvents)

#pragma mark - Keyboard manager delegate

- (void)setupKeyboardObserver
{
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keybWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keybDidShow:) name:UIKeyboardDidShowNotification object:nil];
}


/// Fuck me, sorry for this
- (void)keybWillShow:(NSNotification*)notification
{
	NSValue* endFrame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
	NSNumber* rate = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
	
	if (endFrame == nil || rate == nil) return;
	
	CGRect currentKeyboard = endFrame.CGRectValue;
	CGRect convertedFrame = [self.view convertRect:currentKeyboard fromView:nil];
	
	[self keyboardWillShowWith:convertedFrame.size animationTime:rate.floatValue];
}

- (void)keybDidShow:(NSNotification*)notification
{
	NSValue* endFrame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
	
	// This is a hack to fix weird scrolling bugs on iPhone. Let's make sure the content size is adjusted correctly when keyboard has been shown.
	if (is_Mobile && endFrame != nil) {
		UIEdgeInsets insets = self.textView.contentInset;
		
		CGRect currentKeyboard = endFrame.CGRectValue;
		CGRect convertedFrame = [self.view convertRect:currentKeyboard fromView:nil];
		
		if (insets.bottom < convertedFrame.size.height) {
			insets.bottom = convertedFrame.size.height;
			self.textView.contentInset = insets;
			[self.textView scrollRangeToVisible:self.textView.selectedRange];
		}
	}
}


-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime
{
	// Let's not use this on phones
	if (is_Mobile) return;
	
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, size.height, 0);
	
	CGRect bounds = self.scrollView.bounds;
	bool animateBounds = false;
	
	if (self.selectedRange.location != NSNotFound) {
		CGRect selectionRect = [self.textView rectForRangeWithRange:self.selectedRange];
		CGRect visible = [self.textView convertRect:selectionRect toView:self.scrollView];
		
		CGRect modifiedRect = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height - size.height);
		
		if (CGRectIntersection(visible, modifiedRect).size.height == 0.0) {
			bounds.origin.y += size.height;
			animateBounds = true;
		}
	}
	
	[UIView animateWithDuration:0.0 animations:^{
		self.scrollView.contentInset = insets;
		self.outlineView.contentInset = insets;
		if (animateBounds) self.scrollView.bounds = bounds;
		
	} completion:^(BOOL finished) {
		[self.textView resize];
	}];
}

-(void)keyboardWillHide
{
	self.outlineView.contentInset = UIEdgeInsetsZero;
	self.scrollView.contentInset = UIEdgeInsetsZero;
}



@end
