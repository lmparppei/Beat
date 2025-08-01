//
//  Document+TextEvents.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+TextEvents.h"
#import "Document+UI.h"

@implementation Document (TextEvents)

#pragma mark - Text events

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// Don't allow editing the script while tagging
	if (self.mode != EditMode || self.contentLocked) return NO;
	
	Line* currentLine = self.currentLine;
	
	bool change = true;
	bool undoOperation = self.undoManager.isRedoing || self.undoManager.isUndoing;
	
	// This shouldn't be here :-)
	if (replacementString.length == 1 && affectedCharRange.length == 0 && self.beatTimer.running) {
		if (![replacementString isEqualToString:@"\n"]) self.beatTimer.charactersTyped++;
	}
		
	// Don't allow certain symbols
	if (replacementString.length == 1) {
		unichar c = [replacementString characterAtIndex:0];
		if ([NSCharacterSet.badControlCharacters characterIsMember:c]) return false;
	}
	
	
	// Check for character input trouble
	if (self.characterInput && replacementString.length == 0 && NSMaxRange(affectedCharRange) == self.characterInputForLine.position) {
		[self cancelCharacterInput];
		change = false;
	}
	
	// Don't repeat ) or ]
	else if ([self.textActions shouldJumpOverParentheses:replacementString range:affectedCharRange] &&
		!self.undoManager.redoing && !self.undoManager.undoing) {
		change = false;
	}
	
	// Handle new line breaks (when actually typed)
	else if ([replacementString isEqualToString:@"\n"] && affectedCharRange.length == 0 && !undoOperation) {
		// Line break after character cue
		// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
		if (currentLine.isAnyCharacter && self.automaticContd && [self.textActions shouldAddContdIn:affectedCharRange string:replacementString]) {
			change = false;
		}
		
		// When on a parenthetical, don't split it when pressing enter, but move downwards to next dialogue block element
		// Note: This logic is a bit faulty. We should probably just move on next line regardless of next character
		else if (currentLine.isAnyParenthetical && self.selectedRange.length == 0) {
			if (self.text.length >= affectedCharRange.location + 1) {
				unichar chr = [self.text characterAtIndex:affectedCharRange.location];
				if (chr == ')') {
					NSInteger lineIndex = [self.parser indexOfLine:currentLine];
					[self addString:@"\n" atIndex:affectedCharRange.location + 1];
					if (lineIndex < self.parser.lines.count) [self.formatting formatLine:self.parser.lines[lineIndex]];
					
					[self.textView setSelectedRange:(NSRange){ affectedCharRange.location + 2, 0 }];
					change = false;
				}
			}
		}
		// Process line break after a forced character input
		else if (self.characterInput && self.characterInputForLine && NSMaxRange(self.characterInputForLine.textRange) <= self.text.length) {
			// If the cue is empty, reset it
			if (self.characterInputForLine.string.length == 0) {
				[self setTypeAndFormat:self.characterInputForLine type:empty];
			} else {
				self.characterInputForLine.forcedCharacterCue = YES;
			}
		}
		// Handle automatic line breaks
		else if ([self.textActions shouldAddLineBreaks:currentLine range:affectedCharRange]) {
			change = false;
		}
	}
	
	// Single characters
	else if (replacementString.length == 1 && !undoOperation) {
		// Auto-close () and [[]]
		if (self.matchParentheses) change = ![self.textActions shouldMatchParenthesesIn:affectedCharRange string:replacementString];
	}
	
	// If change is true, we can safely add the string (and parse the addition)
	if (change) {
		// Make the replacement string uppercase in parser
		if (self.characterInput) replacementString = replacementString.uppercaseString;
		
		// Parse changes so far
		[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
		
		self.lastChangedRange = (NSRange){ affectedCharRange.location, replacementString.length };
	}
	
	return change;
}


-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
	if (self.documentIsLoading) return;
	
	if (editedMask & NSTextStorageEditedCharacters) {
		self.lastEditedRange = NSMakeRange(editedRange.location, delta);
		
		// Register changes. Because macOS Sonoma somehow changed attribute handling, we need to _queue_ those changes and
		// then release them when text has changed
		if (self.revisionMode && self.lastChangedRange.location != NSNotFound && !self.undoManager.isUndoing) {
			[self.revisionTracking queueRegisteringChangesInRange:NSMakeRange(editedRange.location, editedRange.length) delta:delta];
		}
	}
}

- (void)textViewDidChangeSelection:(NSNotification *)notification
{
	// If we are just opening the document, do nothing
	if (self.documentIsLoading) return;
	
	Line* currentLine = self.currentLine;
	
	// Reset forced character input
	if (self.characterInputForLine != currentLine && self.characterInput) {
		self.characterInput = NO;
		if (self.characterInputForLine.string.length == 0) {
			[self setTypeAndFormat:self.characterInputForLine type:empty];
			self.characterInputForLine = nil;
		}
	}
	
	// Correct parsing for character cues (we need to move this to parser somehow)
	Line *previouslySelectedLine = self.previouslySelectedLine;
	__weak static Line *previousCue;
	
	if (previouslySelectedLine.isAnyCharacter) {
		previousCue = previouslySelectedLine;
	}
	if (previouslySelectedLine != currentLine && previousCue.isAnyCharacter) {
		[self.parser ensureDialogueParsingFor:previousCue];
	}
	
	// Update hidden Fountain markup
	[self.textView updateMarkupVisibility];
		
	// Scroll to view if needed
	if (self.selectedRange.length == 0) {
		[self.textView scrollRangeToVisible:self.selectedRange];
	}
	
	// Notify observers
	[self updateSelectionObservers];
	
	// We REALLY REALLY should make some sort of cache for these, or optimize outline creation
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Update all views which are affected by the caret position
		[self updateUIwithCurrentScene];
		
		// Update tag view
		if (self.mode == TaggingMode) [self.tagging updateTaggingData];
		
		// Update running plugins
		[self.pluginAgent updatePluginsWithSelection:self.selectedRange];
	});
}


#pragma mark - Spelling

- (IBAction)toggleIgnoreDialogueSpelling:(id)sender
{
	[self toggleSetting:sender];
	
	NSUInteger types = NSTextCheckingTypeSpelling | NSTextCheckingTypeGrammar;
	
	for (Line* line in self.parser.lines) {
		[self.textView checkTextInRange:line.textRange types:types options:@{}];
	}
	
	NSAlert *alert = NSAlert.new;
	alert.showsSuppressionButton = YES;
	
	bool dontAsk = [BeatUserDefaults.sharedDefaults isSuppressed:@"ignoreDialogueSpelling"];
	if (!dontAsk) {
		alert.messageText = [BeatLocalization localizedStringForKey:@"spelling.ignoreDialogue.title"];
		alert.informativeText = [BeatLocalization localizedStringForKey:@"spelling.ignoreDialogue.text"];
		[alert addButtonWithTitle:@"OK"];
		
		[alert runModal];
		if (alert.suppressionButton.state == NSOnState) {
			[BeatUserDefaults.sharedDefaults setSuppressed:@"ignoreDialogueSpelling" value:YES];
		}
	}
}

/*
- (NSInteger)textView:(NSTextView *)textView shouldSetSpellingState:(NSInteger)value range:(NSRange)affectedCharRange
{
	if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingIgnoreSpellCheckingInDialogue]) {
		Line* line = [self.parser lineAtPosition:affectedCharRange.location];
		if (line.isAnyDialogue) return 0;
	}
	
	return 1;
}
*/

#pragma mark - Character input

- (void)cancelCharacterInput
{
	// TODO: Move this to text view
	self.characterInput = NO;
	self.characterInputForLine = nil;
	
	NSMutableDictionary *attributes = NSMutableDictionary.dictionary;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	[attributes setValue:self.fonts.regular forKey:NSFontAttributeName];
	[paragraphStyle setLineHeightMultiple:1.1];
	[paragraphStyle setFirstLineHeadIndent:0];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	[self.textView setTypingAttributes:attributes];
	self.textView.needsDisplay = YES;
	self.textView.needsLayout = YES;
	
	[self setTypeAndFormat:self.characterInputForLine type:empty];
}


#pragma mark - Character cues
// TODO: Move these to text view

- (void)handleTabPress
{
	// TODO: Move this to text view
	// Force character if the line is suitable
	Line *currentLine = self.currentLine;
	
	if (currentLine.isAnyCharacter && currentLine.string.length > 0) {
		[self.formattingActions addOrEditCharacterExtension];
	} else {
		[self forceCharacterInput];
	}
}

- (void)forceCharacterInput
{
	// TODO: Move this to text view
	// Don't allow this to happen twice
	if (self.characterInput) return;
	
	[self.formattingActions addCue];
}



@end
