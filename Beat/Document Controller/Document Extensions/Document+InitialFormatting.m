//
//  Document+InitialFormatting.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+InitialFormatting.h"

@implementation Document (InitialFormatting)


#pragma mark - Formatting

/// Render the newly opened document for editing
-(void)renderDocument
{
	self.textView.editable = false;

	// Begin formatting lines.
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Show a progress bar for longer documents
		if (self.parser.lines.count > 1000) {
			self.progressPanel = [[NSPanel alloc] initWithContentRect:(NSRect){(self.documentWindow.screen.frame.size.width - 300) / 2, (self.documentWindow.screen.frame.size.height - 50) / 2,300,50} styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
			
			self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:(NSRect){  25, 20, 250, 10}];
			self.progressIndicator.indeterminate = NO;
			self.progressIndicator.usesThreadedAnimation = YES;
			
			[self.progressPanel.contentView addSubview:self.progressIndicator];
			
			[self.documentWindow beginSheet:self.progressPanel completionHandler:^(NSModalResponse returnCode) { }];
		}
		
		// Apply document formatting
		[self applyInitialFormatting];
	});
}

/**
 Applies the initial formatting while document is loading. We'll create a temporary formatting object and attributed string to handle rendering off screen, and the text storage contents are put into text view after formatting is complete. This cuts the formatting time for longer documents to half.
 */
-(void)applyInitialFormatting
{
	NSMutableAttributedString* formattedString = [NSMutableAttributedString.alloc initWithAttributedString:self.textView.attributedString];

	self.initialFormatting = [BeatEditorFormatting.alloc initWithTextStorage:formattedString];
	self.initialFormatting.delegate = self;
	
	if (self.parser.lines.count > 0) {
		// Start rendering
		self.progressIndicator.maxValue =  1.0;
		[self formatAsynchronouslyFrom:0 batchSize:500 fullString:self.textView.attributedString.mutableCopy results:NSMutableDictionary.new];
		//[self formatAllWithDelayFrom:0 formattedString:formattedString];
	} else {
		// Empty document, do nothing.
		[self formattingComplete:nil];
	}
}

/// This is how you can format all lines in a concurrent loop. Might help with collaboration mode setup. This is also about 50% faster than the current asynchronous loop thing we're using.
- (void)formatAllAsynchronously
{
	NSMutableAttributedString* fullString = self.textView.attributedString.mutableCopy;
	NSMutableDictionary<NSNumber*, NSAttributedString*>* formattedLines = NSMutableDictionary.new;
	
	[self.parser.lines enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(Line * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) { @autoreleasepool {
		Line* line = self.parser.lines[idx];
		
		NSMutableAttributedString* attrStr = fullString.mutableCopy;
		
		BeatEditorFormatting* formatting = [BeatEditorFormatting.alloc initWithTextStorage:attrStr];
		formatting.delegate = self;
		
		[formatting formatLine:line];
		
		NSRange lineRange = line.range;
		if (NSMaxRange(lineRange) > fullString.length) lineRange = NSMakeRange(lineRange.location, lineRange.length-1);
		
		NSAttributedString* result = [attrStr attributedSubstringFromRange:lineRange];
		@synchronized (formattedLines) {
			formattedLines[@(idx)] = result;
		}
	} }];
	
	NSMutableAttributedString* result = NSMutableAttributedString.new;
	
	for (NSInteger i=0; i<formattedLines.count; i++) {
		NSAttributedString* str = formattedLines[@(i)];
		[result appendAttributedString:str];
	}
	
	[self formattingComplete:result];
}

/// Asynchronous formatting. Takes in an index and formats a bunch of parsed lines starting from that index, applying the formatting attributes to given attributed string. This avoids beach ball when opening a large document.
- (void)formatAllWithDelayFrom:(NSInteger)idx formattedString:(NSMutableAttributedString*)formattedString
{
	NSInteger batchSize = 500;
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		Line *line;
		NSInteger lastIndex = idx;
		
		for (NSInteger i = 0; i < batchSize; i++) {
			// After 1000 lines, hand off the process
			if (i + idx >= self.parser.lines.count) break;
			
			line = self.parser.lines[i + idx];
			lastIndex = i + idx;
			[self.initialFormatting formatLine:line firstTime:YES];
		}
		
		[self.progressIndicator incrementBy:(CGFloat)batchSize / (CGFloat)self.parser.lines.count];
		
		if (line == self.parser.lines.lastObject || lastIndex >= self.parser.lines.count) {
			// If the document is done formatting, complete the loading process.
			[self formattingComplete:formattedString];
		} else {
			// Else render 1000 more lines
			[self formatAllWithDelayFrom:lastIndex + 1 formattedString:formattedString];
		}
	});
}

- (void)formatAsynchronouslyFrom:(NSInteger)idx batchSize:(NSInteger)batchSize fullString:(NSMutableAttributedString*)fullString results:(inout NSMutableDictionary<NSNumber*,NSAttributedString*>* _Nullable)results
{
	if (results == nil) results = NSMutableDictionary.new;
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		__block NSArray* lines = self.parser.safeLines;

		NSRange batchRange = NSMakeRange(idx, batchSize);
		if (NSMaxRange(batchRange) > lines.count) batchRange.length = lines.count - idx;
		
		NSIndexSet* indices = [NSIndexSet.alloc initWithIndexesInRange:batchRange];
		
		[lines enumerateObjectsAtIndexes:indices options:NSEnumerationConcurrent usingBlock:^(Line * _Nonnull line, NSUInteger i, BOOL * _Nonnull stop) {
			NSMutableAttributedString* attrStr = fullString.mutableCopy;
			
			BeatEditorFormatting* formatting = [BeatEditorFormatting.alloc initWithTextStorage:attrStr];
			formatting.delegate = self;
			
			[formatting formatLine:line];
			
			NSRange lineRange = line.range;
			if (NSMaxRange(lineRange) > fullString.length) lineRange = NSMakeRange(lineRange.location, lineRange.length-1);
			
			NSAttributedString* result = [attrStr attributedSubstringFromRange:lineRange];
			@synchronized (results) {
				results[@(i)] = result;
			}
		}];
		
		// Increment progress bar
		[self.progressIndicator incrementBy:(CGFloat)NSMaxRange(batchRange) / (CGFloat)lines.count];
		
		NSInteger lastIndex = NSMaxRange(batchRange);
		if (lastIndex >= self.parser.lines.count - 1) {
			// We've reached the end, let's inform that we can safely stop the process.
			NSMutableAttributedString* text = NSMutableAttributedString.new;
			
			for (NSInteger i=0; i<results.count; i++) {
				NSAttributedString* str = results[@(i)];
				if (str == nil) NSLog(@"MISSING for %lu", i);
				else [text appendAttributedString:str];
			}
			
			[self formattingComplete:text];
		} else {
			// Continue with formatting
			[self formatAsynchronouslyFrom:lastIndex batchSize:batchSize fullString:fullString results:results];
		}
	});
}

- (void)formattingComplete:(NSAttributedString*)formattedString;
{
	if (formattedString != nil) [self.textStorage setAttributedString:formattedString];
	
	// Close progress panel and nil the reference
	if (!self.collaborating) {
		if (self.progressPanel != nil) [self.documentWindow endSheet:self.progressPanel];
		self.progressPanel = nil;
	}
	
	[self loadingComplete];
}

- (bool)disableFormatting
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingDisableFormatting];
}


/*
 
 hei
 saanko jäädä yöksi, mun tarvii levätä
 ennen kuin se alkaa taas
 saanko jäädä yöksi, mun tarvii levätä
 en mä voi mennä enää kotiinkaan
 enkä tiedä onko mulla sellaista ollenkaan
 
 */


@end
