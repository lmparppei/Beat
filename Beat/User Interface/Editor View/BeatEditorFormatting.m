//
//  BeatEditorFormatting.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/*

 This class handles formatting the screenplay in editor view
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatEditorFormatting.h"
#import "ThemeManager.h"
#import "BeatColors.h"
#import "BeatRevisions.h"
#import "BeatTagging.h"
#import "BeatTag.h"
#import "Beat-Swift.h"
#import "BeatMeasure.h"
#import "NSFont+CFTraits.h"

@interface BeatEditorFormatting()
// Paragraph styles are stored as { @(paperSize): { @(type): style } }
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableParagraphStyle*>*>* paragraphStyles;
@end

@implementation BeatEditorFormatting

// DOCUMENT LAYOUT SETTINGS
#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

// Base font settings
#define SECTION_FONT_SIZE 16.0 // base value for section sizes
#define LINE_HEIGHT 1.1

// Set character width
#define CHR_WIDTH 7.25
#define DOCUMENT_WIDTH_MODIFIER 61 * CHR_WIDTH
#define DOCUMENT_WIDTH_A4 59 * CHR_WIDTH
#define DOCUMENT_WIDTH_US 61 * CHR_WIDTH
#define TEXT_INSET_TOP 80

// DOCUMENT LAYOUT SETTINGS
#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

// Title page element indent
#define TITLE_INDENT 10 * CHR_WIDTH

#define CHARACTER_INDENT 20 * CHR_WIDTH
#define PARENTHETICAL_INDENT 17 * CHR_WIDTH
#define DIALOGUE_INDENT 11 * CHR_WIDTH
#define DIALOGUE_RIGHT 47 * CHR_WIDTH

#define DD_CHARACTER_INDENT 30 * CHR_WIDTH
#define DD_PARENTHETICAL_INDENT 26 * CHR_WIDTH
#define DUAL_DIALOGUE_INDENT 22 * CHR_WIDTH
#define DD_RIGHT 59 * CHR_WIDTH

static NSString *underlinedSymbol = @"_";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

+ (CGFloat)editorLineHeight {
	return 16.0;
}

/// Returns paragraph style for given line type
- (NSMutableParagraphStyle*)paragraphStyleForType:(LineType)type {
	Line *tempLine = [Line withString:@"" type:type];
	return [self paragraphStyleFor:tempLine];
}

/// Returns paragraph style for given line
- (NSMutableParagraphStyle*)paragraphStyleFor:(Line*)line {
	if (line == nil) line = [Line withString:@"" type:action];
	
	LineType type = line.type;
	
	// Catch forced character cue
	if (_delegate.characterInputForLine == line && _delegate.characterInput) {
		type = character;
	}
	
	// Extended types for title page fields
	else if (line.isTitlePage && line.titlePageKey.length == 0) {
		type = (LineType)titlePageSubField;
	}
	
	else if (line.type == section) {
		if (line.sectionDepth > 1) {
			type = (LineType)subSection;
		}
	}
	/*
	// This is an idea for storing paragraph styles, but it doesn't seem to work for forced character cues.
	BeatPaperSize paperSize = self.delegate.pageSize;
	NSNumber* paperSizeKey = @(paperSize);
	NSNumber* typeKey = @(type);
		
	// Create dictionary for page size when needed
	if (_paragraphStyles == nil) _paragraphStyles = NSMutableDictionary.new;
	if (_paragraphStyles[paperSizeKey] == nil) _paragraphStyles[paperSizeKey] = NSMutableDictionary.new;
		
	// The style already exists, return the premade value
	if (_paragraphStyles[paperSizeKey][typeKey] != nil) {
		return _paragraphStyles[paperSizeKey][typeKey];
	}
	*/
	
	NSMutableParagraphStyle *style = NSMutableParagraphStyle.new;
	style.minimumLineHeight = BeatEditorFormatting.editorLineHeight;
	
	if (type == lyrics || type == centered || type == pageBreak) {
		style.alignment = NSTextAlignmentCenter;
	}
	else if (type == titlePageSubField) {
		style.firstLineHeadIndent = TITLE_INDENT * 1.25;
		style.headIndent = TITLE_INDENT * 1.25;
	}
	else if (line.isTitlePage) {
		style.firstLineHeadIndent = TITLE_INDENT;
		style.headIndent = TITLE_INDENT;
	}
	else if (type == transitionLine) {
		style.alignment = NSTextAlignmentRight;
	}
	else if (type == character) {
		style.firstLineHeadIndent = CHARACTER_INDENT;
		style.headIndent = CHARACTER_INDENT;
		
	} else if (line.type == parenthetical) {
		style.firstLineHeadIndent = PARENTHETICAL_INDENT;
		style.headIndent = PARENTHETICAL_INDENT;
		style.tailIndent = DIALOGUE_RIGHT;
		
	} else if (line.type == dialogue) {
		// Dialogue block
		style.firstLineHeadIndent = DIALOGUE_INDENT;
		style.headIndent = DIALOGUE_INDENT;
		style.tailIndent = DIALOGUE_RIGHT;
		
	} else if (line.type == dualDialogueCharacter) {
		style.firstLineHeadIndent = DD_CHARACTER_INDENT;
		style.headIndent = DD_CHARACTER_INDENT;
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogueParenthetical) {
		style.firstLineHeadIndent = DD_PARENTHETICAL_INDENT;
		style.headIndent = DD_PARENTHETICAL_INDENT;
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogue) {
		style.firstLineHeadIndent = DUAL_DIALOGUE_INDENT;
		style.headIndent = DUAL_DIALOGUE_INDENT;
		style.tailIndent = DD_RIGHT;
	}
	else if (type == subSection) {
		style.paragraphSpacingBefore = 20.0;
		style.paragraphSpacing = 0.0;
	}
	else if (type == section) {
		style.paragraphSpacingBefore = 30.0;
		style.paragraphSpacing = 0.0;
	}
	
	//_paragraphStyles[paperSizeKey][typeKey] = style;
	
	return style;
}

/// Formats a single line in editor
- (void)formatLine:(Line*)line {
	[self formatLine:line firstTime:NO];
}

- (void)formatLine:(Line*)line firstTime:(bool)firstTime
{ @autoreleasepool {
	/*
	 
	 This method uses a mixture of permanent text attributes and temporary attributes
	 to optimize performance.
	 
	 Colors are set using NSLayoutManager's temporary attributes, while everything else
	 is stored into the attributed string in NSTextStorage.
	 
	 */
	
	// SAFETY MEASURES:
	if (line == nil) return; // Don't do anything if the line is null
	if (line.position + line.string.length > _delegate.textView.string.length) return; // Don't go out of range
	
	NSRange range = line.textRange;
	
	NSTextView *textView = _delegate.textView;
	NSLayoutManager *layoutMgr = textView.layoutManager;
	NSTextStorage *textStorage = textView.textStorage;
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
	NSMutableDictionary *attributes;
	if (firstTime || line.position == textView.string.length) attributes = NSMutableDictionary.new;
	else attributes = [textStorage attributesAtIndex:line.position longestEffectiveRange:nil inRange:line.textRange].mutableCopy;
	
	// Don't overwrite revision attribute
	[attributes removeObjectForKey:BeatRevisions.attributeKey];
	
	if (_delegate.disableFormatting) {
		// Only add bare-bones stuff when formatting is disabled
		[layoutMgr addTemporaryAttribute:NSForegroundColorAttributeName value:themeManager.textColor forCharacterRange:line.range];
		[self renderBackgroundForLine:line clearFirst:NO];
		
		NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:nil];
		[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[attributes setValue:_delegate.courier forKey:NSFontAttributeName];
		//[textView setTypingAttributes:attributes];
		
		if (range.length > 0) [textStorage addAttributes:attributes range:range];
		return;
	}
	
	// Apply paragraph styles
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:line];
	[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	// Do nothing for already formatted empty lines (except remove the background)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0 && line != _delegate.characterInputForLine) {
		[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:line.range];
		return;
	}
	
	// Store the type we are formatting for
	line.formattedAs = line.type;
	
	// Extra rules for character cue input
	if (_delegate.characterInput && _delegate.characterInputForLine == line) {
		// Do some extra checks for dual dialogue
		if (line.length && line.lastCharacter == '^') line.type = dualDialogueCharacter;
		else line.type = character;
		
		NSRange selectedRange = textView.selectedRange;
		
		// Only do this if we are REALLY typing at this location
		// Foolproof fix for a strange, rare bug which changes multiple
		// lines into character cues and the user is unable to undo the changes
		if (NSMaxRange(range) <= selectedRange.location) {
			[textView replaceCharactersInRange:range withString:[textStorage.string substringWithRange:range].uppercaseString];
			line.string = line.string.uppercaseString;
			[textView setSelectedRange:selectedRange];
			
			// Reset attribute because we have replaced the text
			[layoutMgr addTemporaryAttribute:NSForegroundColorAttributeName value:themeManager.textColor forCharacterRange:line.range];
		}
		
		// IF we are hiding Fountain markup, we'll need to adjust the range to actually modify line break range, too.
		// No idea why.
		if (_delegate.hideFountainMarkup) {
			range = line.range;
			if (line == _delegate.parser.lines.lastObject) range = line.textRange; // Don't go out of range
		}
	}
	
	// Apply font face
	if (line.type == section) {
		// Stylize sections & synopses
		CGFloat size = SECTION_FONT_SIZE - (line.sectionDepth - 1);
		
		// Also, make lower sections a bit smaller
		size = size - line.sectionDepth;
		if (size < 15) size = 15.0;
		
		[attributes setObject:[_delegate sectionFontWithSize:size] forKey:NSFontAttributeName];
		
	}
	else if (line.type == synopse) {
		[attributes setObject:_delegate.synopsisFont forKey:NSFontAttributeName];
	}
	else if (line.type == pageBreak) {
		// Format page break - bold
		[attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
		
	}
	else if (line.type == lyrics) {
		// Format lyrics - italic
		[attributes setObject:_delegate.italicCourier forKey:NSFontAttributeName];
	}
	else if (line.type == shot) {
		// Bolded shots
		[attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
	}
	else if (attributes[NSFontAttributeName] != _delegate.courier) {
		// Fall back to default (if not set yet)
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
	}
	
	
	// Overwrite some values by default
	if (![attributes valueForKey:NSForegroundColorAttributeName]) {
		[attributes setObject:themeManager.textColor forKey:NSForegroundColorAttributeName];
	}
	if (![attributes valueForKey:NSFontAttributeName]) {
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
	}
	if (![attributes valueForKey:NSUnderlineStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSUnderlineStyleAttributeName];
	}
	if (![attributes valueForKey:NSStrikethroughStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSStrikethroughStyleAttributeName];
	}
	if (!attributes[NSBackgroundColorAttributeName]) {
		//[attributes setObject:NSColor.clearColor forKey:NSBackgroundColorAttributeName];
		[textStorage addAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor range:range];
	}
	
	// Add selected attributes
	if (range.length > 0) {
		// Line does have content
		[textStorage addAttributes:attributes range:range];
	} else {
		// Line is currently empty. Add attributes ahead.
		if (range.location < textStorage.string.length) {
			range = NSMakeRange(range.location, range.length + 1);
			[textStorage addAttributes:attributes range:range];
		}
	}
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	// (do this earlier, you idiot)
	if (line.string.length == 0 && !firstTime) {
		// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
		Line* previousLine;
		NSInteger lineIndex = [_delegate.parser.lines indexOfObject:line];
		if (lineIndex > 0) previousLine = [_delegate.parser.lines objectAtIndex:lineIndex - 1];
		
		// Keep dialogue input after any dialogue elements
		if (previousLine.isAnyDialogue && previousLine.string.length) {
			if (!previousLine.isDualDialogue) paragraphStyle = [self paragraphStyleForType:dialogue];
			else paragraphStyle = [self paragraphStyleForType:dualDialogue];
		} else {
			[paragraphStyle setFirstLineHeadIndent:0];
			[paragraphStyle setHeadIndent:0];
			[paragraphStyle setTailIndent:0];
		}
		
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[textView setTypingAttributes:attributes];
	}
	
	
	[self applyInlineFormatting:line withAttributes:attributes];
	[self setTextColorFor:line];
	
	// Render backgrounds according to text attributes
	// This is AMAZINGLY slow
	if (!firstTime && line.string.length) {
		[self renderBackgroundForLine:line clearFirst:NO];
	}
} }

- (void)applyInlineFormatting:(Line*)line withAttributes:(NSDictionary*)attributes {
	NSTextStorage *textStorage = _delegate.textView.textStorage;
	
	// Remove underline/strikeout
	if (attributes[NSUnderlineStyleAttributeName] || attributes[NSStrikethroughStyleAttributeName]) {
		// Overwrite strikethrough / underline
		[textStorage addAttribute:NSUnderlineStyleAttributeName value:@0 range:line.textRange];
		[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:line.textRange];
	}
	
	// Stylize headings according to settings
	if (line.type == heading) {
		if (_delegate.headingStyleBold) [textStorage applyFontTraits:NSBoldFontMask range:line.textRange];
		if (_delegate.headingStyleUnderline) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
	}
		
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSItalicFontMask range:globalRange];
	}];
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSBoldFontMask range:globalRange];
	}];
	[line.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSBoldFontMask | NSItalicFontMask range:globalRange];
	}];
	
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSStrikethroughStyleAttributeName value:@1 line:line range:range formattingSymbol:strikeoutSymbolOpen];
	}];
}

#pragma mark - Set foreground color

- (void)setForegroundColor:(NSColor*)color line:(Line*)line range:(NSRange)localRange {
	NSRange globalRange = [self globalRangeFromLocalRange:&localRange inLineAtPosition:line.position];
	
	// Don't go out of range and add attributes
	if (NSMaxRange(localRange) <= line.string.length && localRange.location >= 0 && color != nil) {
		[_delegate.textView.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:globalRange];
	}
	
}

#pragma mark - Text backgrounds (for revisions + tagging)

- (void)renderBackgroundForLines {
	for (Line* line in self.delegate.lines) {
		[self renderBackgroundForLine:line clearFirst:YES];
	}
}

- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	NSLayoutManager *layoutMgr = _delegate.textView.layoutManager;
	NSTextStorage *textStorage = _delegate.textView.textStorage;
	
	//[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:line.range];

	if (clear) {
		// First clear the background attribute if needed
		[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:line.range];
	}
	 
	[layoutMgr addTemporaryAttribute:NSStrikethroughStyleAttributeName value:@0 forCharacterRange:line.range];
	
	if (_delegate.showRevisions || _delegate.showTags) {
		// Enumerate attributes
		[textStorage enumerateAttributesInRange:line.textRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
			if (attrs[BeatRevisions.attributeKey] && _delegate.showRevisions) {
				BeatRevisionItem *revision = attrs[BeatRevisions.attributeKey];
				
				if (revision.type == RevisionAddition) {
					[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:revision.backgroundColor forCharacterRange:range];
				}
				else if (revision.type == RevisionRemovalSuggestion) {
					[layoutMgr addTemporaryAttribute:NSStrikethroughColorAttributeName value:[BeatColors color:@"red"] forCharacterRange:range];
					[layoutMgr addTemporaryAttribute:NSStrikethroughStyleAttributeName value:@1 forCharacterRange:range];
					[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:[[BeatColors color:@"red"] colorWithAlphaComponent:0.125] forCharacterRange:range];
				}
			}
			
			if (attrs[BeatReview.attributeKey]) {
				BeatReviewItem *review = attrs[BeatReview.attributeKey];
				if (!review.emptyReview) {
					NSColor *reviewColor = BeatReview.reviewColor;
					reviewColor = [reviewColor colorWithAlphaComponent:.5];
					[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:reviewColor forCharacterRange:range];
				}
			}
			
			if (attrs[BeatTagging.attributeKey] && _delegate.showTags) {
				BeatTag *tag = attrs[BeatTagging.attributeKey];
				NSColor *tagColor = [BeatTagging colorFor:tag.type];
				tagColor = [tagColor colorWithAlphaComponent:.5];
			   
				[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:tagColor forCharacterRange:range];
			}
		}];
	}
}

- (void)initialTextBackgroundRender {
	if (!_delegate.showTags && !_delegate.showRevisions) return;
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[self renderBackgroundForLines];
	});
}

- (void)setTextColorFor:(Line*)line {
	// Foreground color attributes (NOTE: These are TEMPORARY attributes)
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
	// Set the base font color
	[self setForegroundColor:themeManager.textColor line:line range:NSMakeRange(0, line.length)];
	
	// Heading elements can be colorized using [[COLOR COLORNAME]],
	// so let's respect that first
	if (line.isOutlineElement || line.type == synopse) {
		NSColor *color;
		if (line.color.length > 0) {
			color = [BeatColors color:line.color];
		}
		if (color == nil) {
			if (line.type == section) color = themeManager.sectionTextColor;
			else if (line.type == synopse) color = themeManager.synopsisTextColor;
		}
		
		[self setForegroundColor:color line:line range:NSMakeRange(0, line.length)];
	}
	else if (line.type == pageBreak) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length)];
	}
	
	// Enumerate FORMATTING RANGES and make all of them invisible
	[line.formattingRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:range];
	}];
	
	// Enumerate note ranges and set it as COMMENT color
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self setForegroundColor:themeManager.commentColor line:line range:range];
	}];
	
	// Enumerate title page ranges
	if (line.isTitlePage && line.titleRange.length > 0) {
		[self setForegroundColor:themeManager.commentColor line:line range:line.titleRange];
	}
	
	// Bullets for forced empty lines are invisible, too
	else if ((line.string.containsOnlyWhitespace && line.length >= 2)) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, 2)];
	}
	
	// Color markers
	else if (line.marker.length && line.markerRange.length) {
		NSColor *color = [BeatColors color:line.marker];
		NSRange markerRange = line.markerRange;
		if (color) [self setForegroundColor:color line:line range:markerRange];
	}
}

- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSTextView *textView = _delegate.textView;
	
	NSUInteger symLen = sym.length;
	NSRange effectiveRange;
	
	if (symLen == 0) {
		// Format full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * symLen) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + symLen, range.length - 2 * symLen);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + symLen, 0);
	}
	
	if (key.length) [textView.textStorage addAttribute:key value:value
												 range:[self globalRangeFromLocalRange:&effectiveRange
																	  inLineAtPosition:line.position]];
}



- (void)setFontStyle:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSTextView *textView = _delegate.textView;
	NSTextStorage *textStorage = textView.textStorage;
	
	NSRange effectiveRange;
	
	if (sym.length == 0) {
		// Format the full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * sym.length) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + sym.length, range.length - 2 * sym.length);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + sym.length, 0);
	}
	
	if (key.length) {
		NSRange globalRange = [self globalRangeFromLocalRange:&effectiveRange inLineAtPosition:line.position];
				
		// Add the attribute if needed
		[textStorage enumerateAttribute:key inRange:globalRange options:0 usingBlock:^(id  _Nullable attr, NSRange range, BOOL * _Nonnull stop) {
			if (attr != value) [textStorage addAttribute:key value:value range:range];
		}];
	}
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}

@end
