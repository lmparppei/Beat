//
//  BeatDocumentViewController+TextEvents.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 20.1.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentViewController+TextEvents.h"
#import "Beat-Swift.h"

@implementation BeatDocumentViewController (TextEvents)

/// TODO: Move this to text view?
- (void)handleTabPress
{
	if (self.textView.assistantView.numberOfSuggestions > 0) {
		//Select the first one
		[self.textView.assistantView selectItemAt:0];
		return;
	}
	
	[self.formattingActions addCue];
	
	self.characterInputForLine = self.currentLine;
	self.characterInput = true;
	
	[self.textView updateAssistingViews];
}

- (void)restoreCaret
{
	NSInteger position = [self.documentSettings getInt:DocSettingCaretPosition];
	if (position < self.text.length) {
		[self.textView setSelectedRange:NSMakeRange(position, 0)];
		[self.textView scrollToRange:self.textView.selectedRange];
	}
}


#pragma mark - Text view delegation

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
	return true;
}

/// The main method where changes are parsed.
/// - note: This is different from macOS, where changes are parsed in text view delegate method `shouldChangeText`, meaning they get parsed before anything is actually added to the text view. Changes on iOS are parsed **after** text has hit the text storage, which can cause some headache.
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
	if (self.documentIsLoading) return;
	else if (self.formatting.didProcessForcedCharacterCue) return;
	
	Line* line = [self.parser lineAtPosition:editedRange.location];
	
	// Don't parse anything when editing attributes
	if (editedMask == NSTextStorageEditedAttributes) {
		return;
	} else if (mask_contains(editedMask, NSTextStorageEditedCharacters)) {
		// First store the edited range and register possible changes to the text
		self.lastEditedRange = NSMakeRange(editedRange.location, delta);
		
		// Register changes
		if (self.revisionMode && self.lastChangedRange.location != NSNotFound) {
			[self.revisionTracking registerChangesInRange:NSMakeRange(editedRange.location, self.lastChangedRange.length) delta:delta];
		}
	}
	
	self.processingEdit = true;
	
	NSRange affectedRange = NSMakeRange(NSNotFound, 0);
	NSString* string = @"";
	
	if (editedRange.length == 0 && delta < 0) {
		// Single removal. Note that delta is NEGATIVE.
		NSRange removedRange = NSMakeRange(editedRange.location, labs(delta));
		affectedRange = removedRange;
	} else if (editedRange.length > 0 && labs(delta) >= 0) {
		// Something was replaced.
		NSRange addedRange = editedRange;
		NSRange replacedRange;
		
		// Handle negative and positive delta
		if (delta <= 0) replacedRange = NSMakeRange(editedRange.location, editedRange.length + labs(delta));
		else replacedRange =  NSMakeRange(editedRange.location, editedRange.length - labs(delta));
		
		affectedRange = replacedRange;
		string = [self.text substringWithRange:addedRange];
		
	} else {
		// Something was added.
		if (delta > 1) {
			// Longer addition
			NSRange addedRange = editedRange;
			NSRange replacedRange = NSMakeRange(editedRange.location, editedRange.length - labs(delta));
			affectedRange = replacedRange;
			
			string = [self.text substringWithRange:addedRange];
		}
		else {
			// Single addition
			NSRange addedRange = NSMakeRange(editedRange.location, delta);
			affectedRange = NSMakeRange(editedRange.location, 0);
			string = [self.text substringWithRange:addedRange];
		}
	}
	
	if (affectedRange.length == 0 && self.currentLine == self.characterInputForLine && self.characterInput) {
		string = string.uppercaseString;
	}
	
	// Make sure we're double-formatting .... fix for a silly iOS issue
	if (line != self.formatting.lineBeingFormatted || line == nil) {
		[self.parser parseChangeInRange:affectedRange withString:string];
	}
}

-(void)textViewDidChangeSelection:(UITextView *)textView
{
	// For some reason iOS creates a bogus reference... I don't know. This is a duct-tape fix.
	if (self.characterInputForLine != nil) {
		if (self.currentLine.position == self.characterInputForLine.position) {
			self.characterInputForLine = self.currentLine;
		} else {
			[self.textView cancelCharacterInput];
		}
	}
	
	// If this is not a touch event, scroll to content
	if (!self.textView.floatingCursor) {
		[self textViewDidEndSelection:textView selectedRange:textView.selectedRange];
	}
}

/// Called when touch event *actually* changed the selection
- (void)textViewDidEndSelection:(UITextView *)textView selectedRange:(NSRange)selectedRange
{
	// Let's not do any of this stuff if we're processing an edit. For some reason selection end is posted *before* text change. :--)
	if (self.documentIsLoading) return;
	
	if (!self.processingEdit) {
		if (self.selectedRange.length == 0) [self.textView scrollRangeToVisible:NSMakeRange(NSMaxRange(textView.selectedRange), 0)];
		[self updateSelection];
	}
	
	self.processingEdit = false;
}

/// Call this whenever selection can be safely posted to assisting views and observers
- (void)updateSelection
{
	// Update outline view
	if (self.outlineView.visible) [self.outlineView selectCurrentScene];
	
	// Update text view input view and scroll range to visible
	[self.textView updateAssistingViews];
	
	// Update plugins
	[self.pluginAgent updatePluginsWithSelection:self.selectedRange];
	
	// Show review if needed
	[self showReviewIfNeeded];
}

- (void)textDidChange:(id<UITextInput>)textInput
{
	if (textInput == self.textView) [self textViewDidChange:self.getTextView];
}

-(void)textViewDidChange:(UITextView *)textView
{
	[super textDidChange];

	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView scrollRangeToVisible:self.lastChangedRange];
	
	// Reset last changed range
	self.lastChangedRange = NSMakeRange(NSNotFound, 0);
	
	if (!self.documentIsLoading) [self updateChangeCount:UIDocumentChangeDone];
	
	[self.textView resize];
	
	// We should update selection here
	[self updateSelection];
}

/// Alias for macOS-compatibility
- (BOOL)textView:(BXTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	return [self textView:textView shouldChangeTextInRange:affectedCharRange replacementText:replacementString];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	// We won't allow tabs to be inserted
	if ([text isEqualToString:@"\t"]) {
		[self handleTabPress];
		return false;
	}
	
	bool undoOrRedo = (self.undoManager.isUndoing || self.undoManager.isRedoing);
	bool change = true;
	
	Line* currentLine = self.currentLine;
	
	// Process line break after a forced character input
	if ([text isEqualToString:@"\n"] && self.characterInput && self.characterInputForLine) {
		// If the cue is empty, reset it
		if (self.characterInputForLine.length == 0) {
			self.characterInputForLine.type = empty;
			[self.formatting formatLine:self.characterInputForLine];
		} else {
			self.characterInputForLine.forcedCharacterCue = YES;
		}
	}
	
	if (!undoOrRedo && self.selectedRange.length == 0 && range.length == 0 && [text isEqualToString:@"\n"] && currentLine != nil) {
		// Test if we'll add extra line breaks and exit the method
		if (currentLine.isAnyCharacter && self.automaticContd) {
			// Line break after character cue
			// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
			if ([self.textActions shouldAddContdIn:range string:text]) change = NO;
		} else {
			change = ![self.textActions shouldAddLineBreaks:currentLine range:range];
		}
	}
	else if (self.matchParentheses && [self.textActions shouldMatchParenthesesIn:range string:text]) {
		// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
		change = NO;
	}
	else if ([self.textActions shouldJumpOverParentheses:text range:range]) {
		// Jump over already-typed parentheses and other closures
		change = NO;
	}
	
	if (change) self.lastChangedRange = (NSRange){ range.location, text.length };
	
	return change;
}


#pragma mark - Display reviews
// TODO: Wtf. Move this to the review class. Isn't this just duplicate code?

- (void)showReviewIfNeeded
{
	if (self.text.length == 0 || self.selectedRange.location == self.text.length) return;
	
	NSInteger pos = self.selectedRange.location;
	BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
	
	if (reviewItem && !reviewItem.emptyReview) {
		[self.review showReviewIfNeededWithRange:NSMakeRange(pos, 0) forEditing:NO];
	} else {
		[self.review closePopover];
	}
}


@end
