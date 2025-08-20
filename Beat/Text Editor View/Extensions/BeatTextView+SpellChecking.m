//
//  BeatTextView+SpellChecking.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+SpellChecking.h"
#import "BeatTextView+Popovers.h"
#import "Beat-Swift.h"

@implementation BeatTextView (SpellChecking)

#pragma mark - Spell Checking

- (void)toggleContinuousSpellChecking:(id)sender
{
	[super toggleContinuousSpellChecking:sender];
	[BeatUserDefaults.sharedDefaults saveBool:(self.continuousSpellCheckingEnabled) forKey:BeatSettingContinuousSpellChecking];
}

- (void)handleTextCheckingResults:(NSArray<NSTextCheckingResult *> *)results forRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary<NSTextCheckingOptionKey,id> *)options orthography:(NSOrthography *)orthography wordCount:(NSInteger)wordCount
{
	// Do nothing when autocompletion list is visible
	if (self.popoverController.isShown) return;
	
	Line *line = [self.editorDelegate.parser lineAtIndex:range.location];
	NSArray* newResults = results;
	
	// Avoid capitalizing parentheticals
	if (line.isAnyParenthetical) {
		NSMutableArray<NSTextCheckingResult*> *fixedResults;
		NSString *textToChange = [self.textStorage.string substringWithRange:range];
		
		for (NSTextCheckingResult *result in results) {
			NSTextCheckingType type = result.resultType;
			if (type != NSTextCheckingTypeOrthography) {
				// Make sure the replacement string is not just trying to capitalize our parenthetical.
				NSString* toReplace = [textToChange substringWithRange:result.range].uppercaseString;
				NSString* replacement = result.replacementString.uppercaseString;
				if (![toReplace isEqualToString:replacement] && result.resultType == NSTextCheckingTypeCorrection) {
					[fixedResults addObject:result];
				}
			} else {
				[fixedResults addObject:result];
			}
		}
		
		newResults = fixedResults;
	}
		
	[super handleTextCheckingResults:newResults forRange:range types:checkingTypes options:options orthography:orthography wordCount:wordCount];
}


- (void)checkTextInRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary<NSTextCheckingOptionKey,id> *)options
{
	__block bool check = true;
	__block NSMutableIndexSet* ranges = NSMutableIndexSet.new;
	
	// NOTE: If no specific spelling stuff is on, we'll just rely on the basic spell checker.
	bool ignoreDialogue = [BeatUserDefaults.sharedDefaults getBool:BeatSettingIgnoreSpellCheckingInDialogue];
	if (!ignoreDialogue) {
		[super checkTextInRange:range types:checkingTypes options:options];
		return;
	}

	// Don't go out of range here
	if (range.length == 0 || NSMaxRange(range) > self.text.length) return;
 
	// Do more complicated spell checking
	[self.textStorage enumerateAttribute:@"representedLine" inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;

		// Skip spell checking for this range
		if (line.isAnyDialogue && ignoreDialogue)
			return;
 
		[ranges addIndexesInRange:line.range];
	}];
 
	[ranges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSMaxRange(range) > self.text.length)
			range.length -= NSMaxRange(range) - self.text.length;
		
		if (range.length > 0)
			[super checkTextInRange:range types:checkingTypes options:options];
	}];
}

@end
