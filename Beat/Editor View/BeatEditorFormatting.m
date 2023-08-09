//
//  BeatEditorFormatting.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/**

 This class handles formatting the screenplay in editor view.
 It is also one of the oldest and messiest parts of the whole app. A full rewrite is direly needed.
 
 TODO: Make this OS-agnostic.
 
 */

#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatPagination2/BeatPagination2-Swift.h>

#import "BeatEditorFormatting.h"

@interface BeatEditorFormatting()
// Paragraph styles are stored as { @(paperSize): { @(type): style } }
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableParagraphStyle*>*>* paragraphStyles;
@end

@implementation BeatEditorFormatting

// Base font settings
#define SECTION_FONT_SIZE 16.0 // base value for section sizes
#define LINE_HEIGHT 1.1

// Set character width
#define CHR_WIDTH 7.25
#define TEXT_INSET_TOP 80

#define DIALOGUE_RIGHT 47 * CHR_WIDTH

#define DD_CHARACTER_INDENT 30 * CHR_WIDTH
#define DD_PARENTHETICAL_INDENT 27 * CHR_WIDTH
#define DUAL_DIALOGUE_INDENT 21 * CHR_WIDTH
#define DD_RIGHT 59 * CHR_WIDTH

#define DD_BLOCK_INDENT 0.0
#define DD_BLOCK_CHARACTER_INDENT 9 * CHR_WIDTH
#define DD_BLOCK_PARENTHETICAL_INDENT 6 * CHR_WIDTH

static NSString *underlinedSymbol = @"_";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

static NSString* const BeatRepresentedLineKey = @"representedLine";

+ (CGFloat)editorLineHeight {
	return 16.0;
}
+ (CGFloat)characterLeft {
	return BeatRenderStyles.shared.character.marginLeft;
}
+ (CGFloat)dialogueLeft {
	return BeatRenderStyles.shared.dialogue.marginLeft;
}

-(instancetype)init {
	self = [super init];
	
	
	return self;
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
	
	// We need to get left margin here to avoid issues with extended line types
	if (line.isTitlePage) type = titlePageUnknown;
	RenderStyle* elementStyle = [BeatRenderStyles.editor forElement:[Line typeName:type]];
	
	CGFloat leftMargin = elementStyle.marginLeft;
	CGFloat rightMargin = elementStyle.marginLeft + ((_delegate.pageSize == BeatA4) ? elementStyle.widthA4 : elementStyle.widthLetter);
	
	// Extended types for title page fields and sections
	if (line.isTitlePage && line.titlePageKey.length == 0) {
		type = (LineType)titlePageSubField;
	}
	else if (line.type == section && line.sectionDepth > 1) {
		type = (LineType)subSection;
	}
	

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

	
	NSMutableParagraphStyle *style = NSMutableParagraphStyle.new;
	style.minimumLineHeight = BeatEditorFormatting.editorLineHeight;
	
	style.firstLineHeadIndent = leftMargin;
	style.headIndent = leftMargin;
	if (line.isAnyParenthetical) style.headIndent += CHR_WIDTH;
	
	// TODO: Need to add calculations for tail indents. This is a mess.
	
	if (type == lyrics || type == centered || type == pageBreak) {
		style.alignment = NSTextAlignmentCenter;
	}
	else if (type == titlePageSubField) {
		style.firstLineHeadIndent = leftMargin * 1.25;
		style.headIndent = leftMargin * 1.25;
	}
	else if (line.isTitlePage) {
		style.firstLineHeadIndent = leftMargin;
		style.headIndent = leftMargin;
	}
	else if (type == transitionLine) {
		style.alignment = NSTextAlignmentRight;
		
	} else if (line.type == parenthetical) {
		style.tailIndent = rightMargin;
		
	} else if (line.type == dialogue) {
		style.tailIndent = rightMargin;
		
	} else if (line.type == character) {
		style.tailIndent = rightMargin;
		
	} else if (line.type == dualDialogueCharacter) {
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogueParenthetical) {
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogue) {
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
	
	_paragraphStyles[paperSizeKey][typeKey] = style;
	
	return style;
}

- (void)formatLinesInRange:(NSRange)range
{
	NSArray* lines = [_delegate.parser linesInRange:range];
	for (Line* line in lines) {
		[self formatLine:line];
	}
}

/// Formats a single line in editor
- (void)formatLine:(Line*)line
{
	[self formatLine:line firstTime:NO];
}

- (BXFont* _Nonnull)fontFamilyForLine:(Line*)line {
	static NSDictionary* fonts;
	if (fonts == nil) {
		fonts = @{
			@(synopse): _delegate.synopsisFont,
			@(lyrics): _delegate.italicCourier,
			@(pageBreak): _delegate.boldCourier,
			@(shot): _delegate.boldCourier
		};
	}
	
	BXFont* font;
	
	if (line.type == section) {
		CGFloat size = SECTION_FONT_SIZE - (line.sectionDepth - 1);
		
		// Make lower sections a bit smaller
		size = size - line.sectionDepth;
		if (size < 15) size = 15.0;
		
		font = [_delegate sectionFontWithSize:size];
	}
	else if (fonts[@(line.type)] != nil) {
		font = fonts[@(line.type)];
	}
	else {
		font = _delegate.courier;
	}
	
	return font;
}


- (void)setFontForLine:(Line*)line {
	[self setFontForLine:line force:false];
}
- (void)setFontForLine:(Line*)line force:(bool)force {
	NSTextStorage *textStorage = _delegate.textStorage;
	
	NSRange range = line.textRange;

	BXFont* font = [self fontFamilyForLine:line];
	__block bool resetFont = (force) ? true : false;
	
	if (!resetFont) {
		if (range.length > 0 && line.type != section && line.type != synopse) {
			[textStorage enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
				NSFont* currentFont = value;
				if (![currentFont.familyName isEqualToString:font.familyName]) {
					resetFont = true;
					*stop = true;
					return;
				}
			}];
		} else if (line.type == section || line.type == synopse) {
			resetFont = true;
		}
	}
	
	
	if (resetFont) {
		[textStorage addAttribute:NSFontAttributeName value:font range:range];
	}
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
	if (line.position + line.string.length > _delegate.text.length) return; // Don't go out of range
	
	
	NSRange selectedRange = _delegate.selectedRange;
	ThemeManager *themeManager = ThemeManager.sharedManager;
	NSTextStorage *textStorage = _delegate.textStorage;
	bool alreadyEditing = (textStorage.editedMask != 0);
	alreadyEditing = true;
	
	NSRange range = line.textRange; // range without line break
	NSRange fullRange = line.range; // range WITH line break
	if (NSMaxRange(fullRange) > textStorage.length) fullRange.length--;

	bool forceFont = false;
	if (line.formattedAs != line.type) forceFont = true;
			
	// Current attribute dictionary
	NSMutableDictionary* attributes;
	NSMutableDictionary* newAttributes = NSMutableDictionary.new;
	if (firstTime || line.position == _delegate.text.length) attributes = NSMutableDictionary.new;
	else attributes = [textStorage attributesAtIndex:line.position longestEffectiveRange:nil inRange:line.textRange].mutableCopy;
	
	// Remove some attributes
	[attributes removeObjectForKey:BeatRevisions.attributeKey];
	[attributes removeObjectForKey:BeatReview.attributeKey];
	[attributes removeObjectForKey:BeatRepresentedLineKey];
		
	// Store the represented line
	NSRange representedRange;
	if (range.length > 0) {
		Line* representedLine = [textStorage attribute:BeatRepresentedLineKey atIndex:line.position longestEffectiveRange:&representedRange inRange:range];
		if (representedLine != line || representedRange.length != range.length) {
			forceFont = true;
			[textStorage addAttribute:BeatRepresentedLineKey value:line range:fullRange];
		}
	} else {
		forceFont = true;
		newAttributes[BeatRepresentedLineKey] = line;
	}
		
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:line];
	if (![attributes[NSParagraphStyleAttributeName] isEqualTo:paragraphStyle]) {
		newAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
		
		// Also update the paragraph style to current attributes
		// attributes[NSParagraphStyleAttributeName] = paragraphStyle;
	}

	if (attributes[NSForegroundColorAttributeName] == nil) {
		newAttributes[NSForegroundColorAttributeName] = themeManager.textColor;
	}
	
	// Do nothing for already formatted empty lines (except remove the background)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0 && line != _delegate.characterInputForLine && [paragraphStyle isEqualTo:attributes[NSParagraphStyleAttributeName]]) {
		[_delegate setTypingAttributes:attributes];
		
		// If we need to update the line, do it here
		if (newAttributes[BeatRepresentedLineKey]) {
			[textStorage addAttribute:BeatRepresentedLineKey value:newAttributes[BeatRepresentedLineKey] range:range];
		}
		
		if (!alreadyEditing) [textStorage endEditing];
		
		[self addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor range:line.range];
		return;
	}
	
	// Store the type we are formatting for
	line.formattedAs = line.type;
	
	// Extra rules for character cue input
	
	if (_delegate.characterInput && _delegate.characterInputForLine == line) {
		// Do some extra checks for dual dialogue
		if (line.length && line.lastCharacter == '^') line.type = dualDialogueCharacter;
		else line.type = character;
						
		// Only do this if we are REALLY typing at this location
		// Foolproof fix for a strange, rare bug which changes multiple
		// lines into character cues and the user is unable to undo the changes
		if (NSMaxRange(range) <= selectedRange.location) {
			[_delegate.textStorage replaceCharactersInRange:range withString:[textStorage.string substringWithRange:range].uppercaseString];
			line.string = line.string.uppercaseString;

			[self addTemporaryAttribute:NSForegroundColorAttributeName value:themeManager.textColor range:line.range];
			_delegate.selectedRange = selectedRange;
		}
		
		// IF we are hiding Fountain markup, we'll need to adjust the range to actually modify line break range, too.
		// No idea why.
		if (_delegate.hideFountainMarkup) {
			range = line.range;
			if (line == _delegate.parser.lines.lastObject) range = line.textRange; // Don't go out of range
		}
	}

	// Begin editing attributes
	if (!alreadyEditing) [textStorage beginEditing];
	
	// Add new attributes
	NSRange attrRange = range;
	if (range.length == 0 && range.location < textStorage.string.length) {
		attrRange = NSMakeRange(range.location, range.length + 1);
	}
	
	if (newAttributes.count) {
		[textStorage addAttributes:newAttributes range:attrRange];
	}
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	// If we are editing a dialogue block at the end of the document, the line will be empty.
	// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
	if (line.string.length == 0 && !firstTime &&
		NSLocationInRange(self.delegate.selectedRange.location, line.range)) {
		Line* previousLine;
		
		NSInteger lineIndex = [_delegate.parser.lines indexOfObject:line];
		if (lineIndex > 0 && lineIndex != NSNotFound) previousLine = [_delegate.parser.lines objectAtIndex:lineIndex - 1];
		
		// Keep dialogue input after any dialogue elements
		if (previousLine.isDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dialogue];
		}
		else if (previousLine.isDualDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dualDialogue];
		} else {
			paragraphStyle = [self paragraphStyleFor:line];
		}
		
		attributes[NSParagraphStyleAttributeName] = paragraphStyle;
	} else {
		[attributes removeObjectForKey:NSParagraphStyleAttributeName];
	}
	
	// Set typing attributes
	attributes[NSFontAttributeName] = _delegate.courier;
	
	[_delegate setTypingAttributes:attributes];

	[self applyInlineFormatting:line reset:forceFont];
	[self revisedTextStyleForRange:range];
	if (!alreadyEditing) [textStorage endEditing];
	
	[self setTextColorFor:line];
	[self revisedTextColorFor:line];
} }

- (void)applyInlineFormatting:(Line*)line reset:(bool)reset {
	NSTextStorage *textStorage = _delegate.textStorage;
	NSRange range = NSMakeRange(0, line.length);

	NSAttributedString* astr = line.attributedStringForFDX;
	bool formattingUnchanged = [astr isEqualToAttributedString:line.formattedString];
	if (!reset &&
		formattingUnchanged &&
		!line.isOutlineElement &&
		line.type != synopse &&
		line.type != lyrics) {
		// We've already formatted the string, no need to reformat inline content
		return;
	}
	
	bool force = (!reset && line.noFormatting && formattingUnchanged) ? false : true;
	[self setFontForLine:line force:force];
	line.formattedString = astr;

	
	/*
	// An die Nachgeborenen.
	// Tuleville sukupolville.
	// For future generations.
	 
	// An attempt at reusing parts of the formatted string.
	
	 NSInteger changeAt = _delegate.lastEditedRange.location + _delegate.lastEditedRange.length;

	NSAttributedString* astr = line.attributedStringForFDX;
	if ([astr isEqualToAttributedString:line.formattedString]) {
		// We've already formatted the string, no need to reformat inline content
		return;
	}
	else if (NSLocationInRange(changeAt, line.range) && line.formattedString.length > changeAt - line.position) {
		// If we are editing this string, let's check if we can reuse parts of it
		NSRange headRange = NSMakeRange(0, changeAt - line.position);
		
		NSAttributedString* head = [astr attributedSubstringFromRange:headRange];
		NSAttributedString* oldHead = [line.formattedString attributedSubstringFromRange:headRange];

		if ([head isEqualTo:oldHead]) {
			// Adjust range
			range = NSMakeRange(changeAt - line.position, line.length - (changeAt - line.position));
		} else {
			// Reset font
			[self setFontForLine:line force:true];
		}
	}
	line.formattedString = astr;
	 */
	
	NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
	
	// Remove underline/strikeout
	[textStorage addAttribute:NSUnderlineStyleAttributeName value:@0 range:globalRange];
	[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:globalRange];
	
	// Stylize headings according to settings
	if (line.type == heading) {
		if (_delegate.headingStyleBold) [textStorage applyFontTraits:NSBoldFontMask range:line.textRange];
		if (_delegate.headingStyleUnderline) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
	}
	else if (line.type == lyrics) {
		[textStorage applyFontTraits:NSFontItalicTrait range:line.textRange];
	}
	
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[textStorage applyFontTraits:NSItalicFontMask range:globalRange];
	}];
	[line.boldRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[textStorage applyFontTraits:NSBoldFontMask range:globalRange];
	}];
	[line.boldItalicRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[textStorage applyFontTraits:NSBoldFontMask | NSItalicFontMask range:globalRange];
	}];
	
	[line.underlinedRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
	[line.strikeoutRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSStrikethroughStyleAttributeName value:@1 line:line range:range formattingSymbol:strikeoutSymbolOpen];
	}];
}

#pragma mark - Set foreground color

- (void)setForegroundColor:(NSColor*)color line:(Line*)line range:(NSRange)localRange {
	NSRange globalRange = [line globalRangeFromLocal:localRange];
	
	// Don't go out of range and add attributes
	if (NSMaxRange(localRange) <= line.string.length && localRange.location >= 0 && color != nil) {
		[self addTemporaryAttribute:NSForegroundColorAttributeName value:color range:globalRange];
	}
	
}

#pragma mark - Set temporary attributes

- (void)addTemporaryAttribute:(NSString*)key value:(id)value range:(NSRange)range {
	//[_delegate.layoutManager addTemporaryAttribute:key value:value forCharacterRange:range];
	
	// Don't go out of range
	if (NSMaxRange(range) >= self.delegate.text.length) {
		range.length = self.delegate.textStorage.length - range.location;
	}
	
	if (range.length > 0) [_delegate.textStorage addAttribute:key value:value range:range];
}


#pragma mark - Render dual dialogue

/// Note that this method modifies the `paragraph` pointer
- (void)renderDualDialogueForLine:(Line*)line paragraphStyle:(NSMutableParagraphStyle*)paragraph
{
	return;
/*
	// An die Nachgeborenen.
	// For future generations.
	 
	bool isDualDialogue = false;
	NSArray* dialogueBlocks = [self.delegate.parser dualDialogueFor:line isDualDialogue:&isDualDialogue];
	
	if (!isDualDialogue) return;
	
	NSArray<Line*>* left = dialogueBlocks[0];
	NSArray<Line*>* right = dialogueBlocks[1];
	
	NSDictionary* attrs = [self.delegate.textStorage attributesAtIndex:left.firstObject.position effectiveRange:nil];
	NSMutableParagraphStyle* ddPStyle = [attrs[NSParagraphStyleAttributeName] mutableCopy];
		
	NSTextTable* textTable;
	
	if (ddPStyle == nil) ddPStyle = paragraph;
	if (ddPStyle.textBlocks.count > 0) {
		NSTextTableBlock* b = ddPStyle.textBlocks.firstObject;
		if (b != nil) textTable = b.table;
	}
	
	ddPStyle.tailIndent = 0.0;
	
	if (textTable == nil) {
		textTable = [NSTextTable.alloc init];
		textTable.numberOfColumns = 2;
		[textTable setContentWidth:100.0 type:NSTextBlockPercentageValueType];
	}
	
	CGFloat indent = 0.0;
	if (line.isAnyCharacter) {
		indent = DD_BLOCK_CHARACTER_INDENT;
	}
	else if (line.isAnyParenthetical) {
		indent = DD_BLOCK_PARENTHETICAL_INDENT;
	}
	
	ddPStyle.headIndent = indent;
	ddPStyle.firstLineHeadIndent = indent;
	ddPStyle.tailIndent = 0.0;
	[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:ddPStyle range:line.range];
	
	NSTextTableBlock* leftCell = [[NSTextTableBlock alloc] initWithTable:textTable startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
	NSTextTableBlock* rightCell = [[NSTextTableBlock alloc] initWithTable:textTable startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
	
	[leftCell setContentWidth:50.0 type:NSTextBlockPercentageValueType];
	[rightCell setContentWidth:50.0 type:NSTextBlockPercentageValueType];
		
	NSRange leftRange = NSMakeRange(left.firstObject.position, NSMaxRange(left.lastObject.range) - left.firstObject.position);
	NSRange rightRange = NSMakeRange(right.firstObject.position, NSMaxRange(right.lastObject.range) - right.firstObject.position);
		
	[self.delegate.textStorage enumerateAttribute:NSParagraphStyleAttributeName inRange:leftRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		
		pStyle.textBlocks = @[leftCell];
		pStyle.tailIndent = 0.0;
		
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];
	[self.delegate.textStorage enumerateAttribute:NSParagraphStyleAttributeName inRange:rightRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		pStyle.textBlocks = @[rightCell];
		
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];

	*/
	/*
	
	
	for (Line* l in left) {
		NSLog(@" --> %@", l);
		NSDictionary* a = [self.delegate.textStorage attributesAtIndex:l.position effectiveRange:nil];
		NSMutableParagraphStyle* pStyle = [a[NSParagraphStyleAttributeName] mutableCopy];
		
		if (pStyle.textBlocks.firstObject != leftCell) pStyle.textBlocks = @[leftCell];
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:l.range];
	}
	
	
	for (Line* l in right) {
		NSLog(@" --> %@", l);
		NSDictionary* a = [self.delegate.textStorage attributesAtIndex:l.position effectiveRange:nil];
		NSMutableParagraphStyle* pStyle = [a[NSParagraphStyleAttributeName] mutableCopy];
		
		if (pStyle.textBlocks.firstObject != rightCell) pStyle.textBlocks = @[rightCell];
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:line.range];
	}
	*/
}


#pragma mark - Text color

- (void)setTextColorFor:(Line*)line {
	// Foreground color attributes (NOTE: These are TEMPORARY attributes)
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
	if (line.omitted && !line.note) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length)];
		return;
	}
		
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
		
	NSArray* notes = line.noteData;
	for (BeatNoteData* note in notes) {
		NSRange range = note.range;
		NSColor* color = themeManager.commentColor;
		
		if (note.color) {
			NSColor* c = [BeatColors color:note.color];
			if (c != nil) color = c;
		}
		
		if (range.length > 0) [self setForegroundColor:color line:line range:range];
	}
	
	// Enumerate title page ranges
	if (line.isTitlePage && line.titleRange.length > 0) {
		[self setForegroundColor:themeManager.commentColor line:line range:line.titleRange];
	}
	
	// Bullets for forced empty lines are invisible, too
	else if ((line.string.containsOnlyWhitespace && line.length >= 2)) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length)];
	}
	
	// Color markers
	else if (line.markerRange.length) {
		NSColor *color;
				
		if (line.marker.length == 0) color = [BeatColors color:@"orange"];
		else color = [BeatColors color:line.marker];
		
		NSRange markerRange = line.markerRange;
		
		if (color) [self setForegroundColor:color line:line range:markerRange];
	}
	
}

- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
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
	
	if (key.length) [_delegate.textStorage addAttribute:key value:value range:[line globalRangeFromLocal:effectiveRange]];
}


- (void)setFontStyle:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSTextStorage *textStorage = _delegate.textStorage;
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
		NSRange globalRange = [line globalRangeFromLocal:effectiveRange];
				
		// Add the attribute if needed
		[textStorage enumerateAttribute:key inRange:globalRange options:0 usingBlock:^(id  _Nullable attr, NSRange range, BOOL * _Nonnull stop) {
			if (attr != value) {
				[textStorage addAttribute:key value:value range:range];
			}
		}];
	}
}


#pragma mark - Revision colors

- (void)revisedTextStyleForRange:(NSRange)globalRange {
	[_delegate.textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:globalRange];
	
	NSTextStorage* textStorage = _delegate.textStorage;
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:globalRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision.type == RevisionRemovalSuggestion) {
			[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
			[textStorage addAttribute:NSStrikethroughColorAttributeName value:BeatColors.colors[@"red"] range:range];
		}
	}];
}
- (void)revisedTextColorFor:(Line*)line {
	if (![BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor]) return;
	
	NSTextStorage *textStorage = _delegate.textStorage;
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:line.textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
		NSColor* color = BeatColors.colors[revision.colorName];
		if (color == nil) return;
		
		[self addTemporaryAttribute:NSForegroundColorAttributeName value:color range:range];
	}];
}

- (void)refreshRevisionTextColors {
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:NSMakeRange(0, _delegate.text.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
		NSColor* color = BeatColors.colors[revision.colorName];
		if (color == nil) return;
		
		if (_delegate.showRevisedTextColor) [self addTemporaryAttribute:NSForegroundColorAttributeName value:color range:range];
		else [_delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:range];
	}];
}

- (void)refreshRevisionTextColorsInRange:(NSRange)range {
	[self revisedTextStyleForRange:range];
	
	NSArray* lines = [_delegate.parser linesInRange:range];
	for (Line* line in lines) {
		[self revisedTextColorFor:line];
	}
}


#pragma mark - Forced dialogue

- (void)forceEmptyCharacterCue
{
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleForType:character];
	paragraphStyle.maximumLineHeight = BeatEditorFormatting.editorLineHeight;
	paragraphStyle.firstLineHeadIndent = BeatEditorFormatting.characterLeft;
	
	[self.delegate.getTextView setTypingAttributes:@{ NSParagraphStyleAttributeName: paragraphStyle, NSFontAttributeName: _delegate.courier } ];
}

@end

/*
 
 takana on eteenpäin
 lautturi meitä odottaa
 tämä joki
 se upottaa
 
 */
