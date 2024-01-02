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

#import <BeatCore/BeatRevisions.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatFonts.h>
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatTextIO.h>
#import <BeatCore/BeatMeasure.h>

#import "BeatEditorFormatting.h"

// Set character width
#define CHR_WIDTH 7.25
// Base font settings
#define SECTION_FONT_SIZE 17.0 // base value for section sizes
#define DD_RIGHT 59 * CHR_WIDTH

@interface BeatEditorFormatting()
// Paragraph styles are stored as { @(paperSize): { @(type): style } }
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableParagraphStyle*>*>* paragraphStyles;
@property (nonatomic) NSMutableAttributedString* textStorage;
@property (nonatomic) BeatFonts* fonts;
@end

@implementation BeatEditorFormatting

static NSString *underlinedSymbol = @"_";
static NSString* const BeatRepresentedLineKey = @"representedLine";

/// This initializer can be used for formatting the text beforehand. If you are NOT using an editor delegate, remember to set `.staticParser` as well.
-(instancetype)initWithTextStorage:(NSMutableAttributedString*)textStorage
{
	self = [super init];
	_textStorage = textStorage;
	
	return self;
}


#pragma mark - Setters and getters

- (BeatFonts *)fonts
{
    if (_delegate != nil) return _delegate.fonts;
    else return BeatFonts.sharedFonts;
}

- (void)setParser:(ContinuousFountainParser *)parser { _staticParser = parser; }
- (ContinuousFountainParser*)parser
{
    if (_delegate != nil) return _delegate.parser;
    else return _staticParser;
}

- (BeatStylesheet*)editorStyles
{
    if (_delegate != nil) return _delegate.editorStyles;
    return BeatStyles.shared.defaultEditorStyles;
}

- (BeatPaperSize)pageSize
{
    if (_delegate != nil) return _delegate.pageSize;
    return [BeatUserDefaults.sharedDefaults getInteger:BeatSettingDefaultPageSize];
}

- (BXFont*)regular { return (_delegate != nil) ? _delegate.fonts.regular : BeatFonts.sharedFonts.regular; }
- (BXFont*)bold { return (_delegate != nil) ? _delegate.fonts.bold : BeatFonts.sharedFonts.bold; }
- (BXFont*)italic { return (_delegate != nil) ? _delegate.fonts.italic : BeatFonts.sharedFonts.italic; }
- (BXFont*)boldItalic { return (_delegate != nil) ? _delegate.fonts.boldItalic : BeatFonts.sharedFonts.boldItalic; }
- (BXFont*)synopsisFont { return (_delegate != nil) ? _delegate.fonts.synopsisFont : BeatFonts.sharedFonts.synopsisFont; }


#pragma mark - Paragraph styles

/// Returns paragraph style for given line type
- (NSMutableParagraphStyle*)paragraphStyleForType:(LineType)type {
	Line *tempLine = [Line withString:@"" type:type];
	return [self paragraphStyleFor:tempLine];
}

/// Returns paragraph style for given line
- (NSMutableParagraphStyle*)paragraphStyleFor:(Line*)line
{
	if (line == nil) line = [Line withString:@"" type:action];
	
	LineType type = line.type;
    BeatPaperSize paperSize = self.pageSize;
    BeatStylesheet* styles = self.editorStyles;
    
    Line* prevLine; // We'll look up previous line ONLY IF NEEDED. It will be NULL for anything else.
    
	// Catch forced character cue
	if (_delegate.characterInputForLine == line && _delegate.characterInput) type = character;
	
	// We need to get left margin here to avoid issues with extended line types
	if (line.isTitlePage) type = titlePageUnknown;
	RenderStyle* elementStyle = [styles forElement:[Line typeName:type]];
	
	// Paragraph sizing
	CGFloat width = [elementStyle widthWithPageSize:_delegate.pageSize];
	if (width == 0.0) width = [styles.page defaultWidthWithPageSize:paperSize];
		
	CGFloat leftMargin = elementStyle.marginLeft;
	CGFloat rightMargin = leftMargin + width - elementStyle.marginRight;
	
	// Extended types for title page fields and sections
    if (line.isTitlePage && line.titlePageKey.length == 0) {
        type = (LineType)titlePageSubField;
    }
    else if (line.type == section && line.sectionDepth > 1) {
        type = (LineType)subSection;
    }
    // In some cases we'll have to create different keys
    else if (elementStyle.unindentFreshParagraphs) {
        // Check the previous line
        prevLine = [self.delegate.parser previousLine:line];
        if (prevLine.type != line.type) {
            type = type + 100;
        }
    }
    
    // We'll cache the paragraph styles when possible
	NSNumber* paperSizeKey = @(paperSize);
	NSNumber* typeKey = @(type);
        
	// Let's create two-dimensional dictionary for each type of element, with page size as key.
    // Paragraph styles are then reused when possible.
	if (_paragraphStyles == nil) _paragraphStyles = NSMutableDictionary.new;
	if (_paragraphStyles[paperSizeKey] == nil) _paragraphStyles[paperSizeKey] = NSMutableDictionary.new;
		
	// This style already exists, return the premade value
	if (_paragraphStyles[paperSizeKey][typeKey] != nil) {
		return _paragraphStyles[paperSizeKey][typeKey];
	}

	// Create paragraph style
	NSMutableParagraphStyle *style = NSMutableParagraphStyle.new;
	style.minimumLineHeight = styles.page.lineHeight;
    	
	// Alignment
	if ([elementStyle.textAlign isEqualToString:@"center"]) style.alignment = NSTextAlignmentCenter;
	else if ([elementStyle.textAlign isEqualToString:@"right"]) style.alignment = NSTextAlignmentRight;

	// Indents are used as left/right margins, and indents in stylesheet are appended to that
	style.firstLineHeadIndent = leftMargin + elementStyle.firstLineIndent;
	style.headIndent = leftMargin + elementStyle.indent;
	style.tailIndent = rightMargin;
    	
    // Unindent novel paragraphs
    if (elementStyle.unindentFreshParagraphs && prevLine.type != line.type) {
        style.firstLineHeadIndent -= elementStyle.firstLineIndent;
    }
    
	if (line.isAnyParenthetical) style.headIndent += CHR_WIDTH;
	
	if (type == titlePageSubField) {
		style.firstLineHeadIndent = leftMargin * 1.25;
		style.headIndent = leftMargin * 1.25;
	}
	else if (type == subSection) {
		style.paragraphSpacingBefore = styles.page.lineHeight;
		style.paragraphSpacing = 0.0;
	}
	else if (type == section) {
		style.paragraphSpacingBefore = styles.page.lineHeight * 1.5;
		style.paragraphSpacing = 0.0;
	}
	
	_paragraphStyles[paperSizeKey][typeKey] = style;
	
	return style;
}

#pragma mark - Formatting shorthands

/// Forces reformatting of each line
- (void)formatAllLines
{
    for (Line* line in self.parser.lines) {
        line.formattedAs = -1; // Force font change
        @autoreleasepool { [self formatLine:line]; }
    }
    
    [self.parser.changedIndices removeAllIndexes];
    [self.delegate ensureLayout];
}

/// Reapplies all paragraph styles
- (void)resetSizing
{
    self.paragraphStyles = nil;
    for (Line* line in self.parser.lines) {
        NSMutableParagraphStyle* pStyle = [self paragraphStyleFor:line];
        // Don't go over bounds
        NSRange range = (NSMaxRange(line.range) <= self.delegate.text.length) ? line.range : line.textRange;
        [self.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
    }
}

/// Formats all lines of given type
- (void)formatAllLinesOfType:(LineType)type
{
	for (Line* line in self.parser.lines) {
        if (line.type == type) {
            line.formattedAs = -1; // Force font change
            [self formatLine:line];
        }
	}
	
	[self.delegate ensureLayout];
}

/// Reformats all lines in given range
- (void)formatLinesInRange:(NSRange)range
{
    NSArray* lines = [self.parser linesInRange:range];
    for (Line* line in lines) {
        [self formatLine:line];
    }
}

#pragma mark - Format a single line

/// Formats a single line in editor
- (void)formatLine:(Line*)line
{
	[self formatLine:line firstTime:NO];
}

- (BXFont* _Nonnull)fontFamilyForLine:(Line*)line {
	NSDictionary* fonts = @{
        @(synopse): self.synopsisFont,
        @(lyrics): self.italic,
        @(pageBreak): self.bold
    };
	
	BXFont* font;
	
	// Section fonts are generated on the fly
	if (line.type == section) {
		CGFloat size = SECTION_FONT_SIZE - (line.sectionDepth - 1) * 1.2;
		
		// Make lower sections a bit smaller
		//size = size - line.sectionDepth;
		if (size < 13) size = 13.0;
		
        font = (_delegate != nil) ? [_delegate.fonts sectionFontWithSize:size] : BeatFonts.sharedFonts.sectionFont;
	}
	else if (fonts[@(line.type)] != nil) {
		// Check if we have stored a specific font for this line type
		font = fonts[@(line.type)];
	}
	else {
		// Otherwise use plain courier
		font = self.regular;
	}
    
	return font;
}

/// Sets the font for given line (if needed)
- (void)setFontForLine:(Line*)line {
	[self setFontForLine:line force:false];
}
/// Sets the font for given line. You can force it if needed.
- (void)setFontForLine:(Line*)line force:(bool)force {
    NSMutableAttributedString *textStorage = self.textStorage;
	
	NSRange range = line.textRange;

	BXFont* font = [self fontFamilyForLine:line];
	__block bool resetFont = (force) ? true : false;
	
	if (!resetFont) {
		if (range.length > 0 && line.type != section && line.type != synopse) {
			[textStorage enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
				BXFont* currentFont = value;
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
	
	// Avoid extra work and only add the font attribute when needed
	if (resetFont) [textStorage addAttribute:NSFontAttributeName value:font range:range];
}

/// Formats one line of screenplay.
/// - note We're using `NSMutableAttributedString` in place of text storage to support ahead-of-time rendering.
- (void)formatLine:(Line*)line firstTime:(bool)firstTime
{ @autoreleasepool {
	// SAFETY MEASURES:
	if (line == nil) return; // Don't do anything if the line is null
	if (_textStorage == nil && line.position + line.string.length > _delegate.text.length) return; // Don't go out of range when attached to an editor
    
	NSRange selectedRange = _delegate.selectedRange;
	ThemeManager *themeManager = ThemeManager.sharedManager;
    NSMutableAttributedString *textStorage = self.textStorage;
    
    // Get editing status from delegate
	bool alreadyEditing = (_delegate.textStorage.editedMask != 0);
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
	
	// Remove some attributes so they won't get overwritten
	[attributes removeObjectForKey:BeatRevisions.attributeKey];
	[attributes removeObjectForKey:BeatReview.attributeKey];
	[attributes removeObjectForKey:BeatRepresentedLineKey];
		
	// Store the represented line
	NSRange representedRange;
	if (range.length > 0) {
		Line* representedLine = [textStorage attribute:BeatRepresentedLineKey atIndex:line.position longestEffectiveRange:&representedRange inRange:range];
		if (representedLine != line || representedRange.length != range.length) {
			//forceFont = true;
			[textStorage addAttribute:BeatRepresentedLineKey value:line range:fullRange];
		}
	} else {
		forceFont = true;
		newAttributes[BeatRepresentedLineKey] = line;
	}
		
    // Create paragraph style
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:line];
    
    // Add to attributes if needed
	if (![attributes[NSParagraphStyleAttributeName] _equalTo:paragraphStyle]) {
		newAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
		// Also update the paragraph style to current attributes
		// attributes[NSParagraphStyleAttributeName] = paragraphStyle;
	}
    
    // Foreground color
	if (attributes[NSForegroundColorAttributeName] == nil) {
		newAttributes[NSForegroundColorAttributeName] = themeManager.textColor;
	}
    
	// Do nothing for already formatted empty lines (except remove the background)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0 && line != _delegate.characterInputForLine && [paragraphStyle _equalTo:attributes[NSParagraphStyleAttributeName]]) {
		[_delegate setTypingAttributes:attributes];
		
		// If we need to update the line, do it here
		if (newAttributes[BeatRepresentedLineKey]) {
			[textStorage addAttribute:BeatRepresentedLineKey value:newAttributes[BeatRepresentedLineKey] range:range];
		}
		
		if (!alreadyEditing) [textStorage endEditing];
		
		[self addAttribute:NSBackgroundColorAttributeName value:BXColor.clearColor range:line.range];
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
		// Foolproof fix for a strange, rare bug which changes multiple lines into character cues and the user is unable to undo the changes
		if (NSMaxRange(range) <= selectedRange.location) {
            self.didProcessForcedCharacterCue = true; // Flag that we're processing a character cue (to avoid reparsing the change on iOS)
			[self.textStorage replaceCharactersInRange:range withString:[textStorage.string substringWithRange:range].uppercaseString];
			line.string = line.string.uppercaseString;
            self.didProcessForcedCharacterCue = false; // End processing

            line.string = line.string.uppercaseString;
            
            #if TARGET_OS_IOS
                // On iOS we need to reset the caret position
                [_delegate setSelectedRange:selectedRange];
            #else
                // And on macOS we need to set the color (no idea why)
                [self addAttribute:NSForegroundColorAttributeName value:themeManager.textColor range:line.range];
            #endif

			_delegate.selectedRange = selectedRange;
		}
		
		// IF we are hiding Fountain markup, we'll need to adjust the range to actually modify line break range, too.
		// No idea why.
		if (_delegate.hideFountainMarkup) {
			range = line.range;
			if (line == self.parser.lines.lastObject) range = line.textRange; // Don't go out of range
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
		
		NSInteger lineIndex = [self.parser.lines indexOfObject:line];
		if (lineIndex > 0 && lineIndex != NSNotFound) previousLine = [self.parser.lines objectAtIndex:lineIndex - 1];
		
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
	attributes[NSFontAttributeName] = _delegate.fonts.regular;
	
	[_delegate setTypingAttributes:attributes];

	[self applyInlineFormatting:line reset:forceFont textStorage:textStorage];
	[self revisedTextStyleForRange:range];
	
	[self setTextColorFor:line];

    if (!alreadyEditing) [textStorage endEditing];
    
} }

- (void)applyInlineFormatting:(Line*)line reset:(bool)reset textStorage:(NSMutableAttributedString*)textStorage
{
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
		// Bolded or not?
        bool boldedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
        bool underlinedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];

        if (boldedHeading) [self applyTrait:BXBoldFontMask range:line.textRange textStorage:textStorage];
        else [self applyTrait:0 range:line.textRange textStorage:textStorage];
        
		if (underlinedHeading) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
        
	} else if (line.type == shot) {
        bool boldedShot = [BeatUserDefaults.sharedDefaults getBool:BeatSettingShotStyleBold];
        bool underlinedShot = [BeatUserDefaults.sharedDefaults getBool:BeatSettingShotStyleUnderlined];
        
        if (boldedShot) [self applyTrait:BXBoldFontMask range:line.textRange textStorage:textStorage];
        else [self applyTrait:0 range:line.textRange textStorage:textStorage];
        if (underlinedShot) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
        
    }
	else if (line.type == lyrics) {
		[self applyTrait:BXItalicFontMask range:line.textRange textStorage:textStorage];
	}
	
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[self applyTrait:BXItalicFontMask range:globalRange textStorage:textStorage];
	}];
	[line.boldRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[self applyTrait:BXBoldFontMask range:globalRange textStorage:textStorage];
	}];
	[line.boldItalicRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
		[self applyTrait:BXBoldFontMask | BXItalicFontMask range:globalRange textStorage:textStorage];
	}];
	
	[line.underlinedRanges enumerateRangesInRange:range options: 0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
}

- (void)applyTrait:(NSUInteger)trait range:(NSRange)range textStorage:(NSMutableAttributedString*)textStorage
{
#if TARGET_OS_IOS
    // NSLayoutManager doesn't have traits on iOS
	if ((trait & BXBoldFontMask) == BXBoldFontMask && (trait & BXItalicFontMask) == BXBoldFontMask) {
        [textStorage addAttribute:NSFontAttributeName value:self.boldItalic range:range];
	} else if (trait == BXItalicFontMask) {
        [textStorage addAttribute:NSFontAttributeName value:self.italic range:range];
	} else if (trait == BXBoldFontMask) {
        [textStorage addAttribute:NSFontAttributeName value:self.bold range:range];
    } else {
        [textStorage addAttribute:NSFontAttributeName value:self.regular range:range];
    }
#else
    // NSLayoutManager DOES have traits on macOS
	[textStorage applyFontTraits:trait range:range];
#endif
}

#pragma mark - Set foreground color

- (void)setForegroundColor:(BXColor*)color line:(Line*)line range:(NSRange)localRange {
	NSRange globalRange = [line globalRangeFromLocal:localRange];
	
	// Don't go out of range and add attributes
	if (NSMaxRange(localRange) <= line.string.length && localRange.location >= 0 && color != nil) {
		[self addAttribute:NSForegroundColorAttributeName value:color range:globalRange];
	}
	
}

#pragma mark - Set temporary attributes

- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range {
	// Don't go out of range
	if (NSMaxRange(range) >= self.delegate.text.length) {
		range.length = self.textStorage.length - range.location;
	}
	
	if (range.length > 0) [self.textStorage addAttribute:key value:value range:range];
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
	// Foreground color attributes
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
		BXColor *color;
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
	
	// Enumerate MACRO RANGES
	[line.macroRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self setForegroundColor:themeManager.macroColor line:line range:range];
	}];
	
	NSArray* notes = line.noteData;
	for (BeatNoteData* note in notes) {
		NSRange range = note.range;
		BXColor* color = themeManager.commentColor;
		
		if (note.color) {
			BXColor* c = [BeatColors color:note.color];
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
		BXColor *color;
				
		if (line.marker.length == 0) color = [BeatColors color:@"orange"];
		else color = [BeatColors color:line.marker];
		
		NSRange markerRange = line.markerRange;
		
		if (color) [self setForegroundColor:color line:line range:markerRange];
	}
    
    [self revisedTextColorFor:line];
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
	
	if (key.length) [self.textStorage addAttribute:key value:value range:[line globalRangeFromLocal:effectiveRange]];
}


- (void)setFontStyle:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
    NSMutableAttributedString *textStorage = self.textStorage;
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


#pragma mark - Get text storage

-(NSMutableAttributedString *)textStorage {
	if (_textStorage) return _textStorage;
	else return _delegate.textStorage;
}


#pragma mark - Revision colors

- (void)revisedTextStyleForRange:(NSRange)globalRange {
    NSMutableAttributedString* textStorage = self.textStorage;
    
    [textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:globalRange];
	
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
	
    NSMutableAttributedString *textStorage = self.textStorage;
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:line.textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
		BXColor* color = BeatColors.colors[revision.colorName];
		if (color == nil) return;
		
		[self addAttribute:NSForegroundColorAttributeName value:color range:range];
	}];
}

- (void)refreshRevisionTextColors {
    [self refreshRevisionTextColorsInRange:NSMakeRange(0, self.delegate.text.length)];
}

- (void)refreshRevisionTextColorsInRange:(NSRange)range {
	[self revisedTextStyleForRange:range];
	
	NSArray* lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
        [self setTextColorFor:line];
	}
}


#pragma mark - Forced dialogue

- (void)forceEmptyCharacterCue
{
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleForType:character];
	paragraphStyle.maximumLineHeight = _delegate.editorStyles.page.lineHeight;
	paragraphStyle.firstLineHeadIndent = _delegate.editorStyles.character.marginLeft;
	
	[self.delegate.getTextView setTypingAttributes:@{ NSParagraphStyleAttributeName: paragraphStyle, NSFontAttributeName: _delegate.fonts.regular } ];
}

@end

/*
 
 takana on eteenpäin
 lautturi meitä odottaa
 tämä joki
 se upottaa
 
 */
