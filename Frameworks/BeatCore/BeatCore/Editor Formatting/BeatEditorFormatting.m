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
 
 */

#import <BeatCore/BeatRevisions.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatTextIO.h>
#import <BeatCore/BeatMeasure.h>

#import "BeatEditorFormatting.h"

// Set character width
#define CHR_WIDTH 7.25

@interface BeatEditorFormatting()
// Paragraph styles are stored as { @(paperSize): { @(type): style } }
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableParagraphStyle*>*>* paragraphStyles;
@property (nonatomic) NSMutableAttributedString* textStorage;
@property (nonatomic) BeatFontSet* fonts;
@property (nonatomic) NSMutableIndexSet* linesToFormat;
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

- (BeatFontSet *)fonts
{
    if (_delegate != nil) return _delegate.fonts;
    else return BeatFontManager.shared.defaultFonts;
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

- (BXFont*)regular { return (_delegate != nil) ? self.fonts.regular : BeatFontManager.shared.defaultFonts.regular; }
- (BXFont*)bold { return (_delegate != nil) ? self.fonts.bold : BeatFontManager.shared.defaultFonts.bold; }
- (BXFont*)italic { return (_delegate != nil) ? self.fonts.italic : BeatFontManager.shared.defaultFonts.italic; }
- (BXFont*)boldItalic { return (_delegate != nil) ? self.fonts.boldItalic : BeatFontManager.shared.defaultFonts.boldItalic; }
- (BXFont*)synopsisFont { return (_delegate != nil) ? self.fonts.synopsis : BeatFontManager.shared.defaultFonts.synopsis; }


#pragma mark - Formatting calls

- (void)applyFormatChanges
{
    ContinuousFountainParser* parser = self.delegate.parser;
    NSArray* lines = parser.lines;
    
    while (parser.changedIndices.count > 0) {
        NSInteger idx = parser.changedIndices.firstIndex;
        [parser.changedIndices removeIndex:idx];
        
        if (idx < lines.count) [self formatLine:lines[idx]];
        else break;
    }
    
    [parser.changedIndices removeAllIndexes];
}


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

    // bool hasRightToLeftText = line.string.hasRightToLeftText;

    Line* prevLine; // We'll look up previous line ONLY IF NEEDED. It will be NULL for anything else.
    
    // Catch forced character cue
    if (_delegate.characterInputForLine == line && _delegate.characterInput) type = character;
    
    // We need to get left margin here to avoid issues with extended line types
    if (line.isTitlePage) type = titlePageUnknown;
    NSString* typeName = [Line typeName:type];
    RenderStyle* elementStyle = [styles forElement:(typeName != nil) ? typeName : @"action"];
    
    // Paragraph sizing
    CGFloat width = [elementStyle widthWithPageSize:_delegate.pageSize];
    if (width == 0.0) width = [styles.page defaultWidthWithPageSize:paperSize];
    
    CGFloat leftMargin = elementStyle.marginLeft;
    CGFloat rightMargin = leftMargin + width - elementStyle.marginRight;
    
    // Extended types for title page fields and sections
    if (line.isTitlePage && line.titlePageKey.length == 0) {
        type = (LineType)titlePageSubField;
    } else if (line.type == section && line.sectionDepth > 1) {
        type = (LineType)subSection;
    }
    // In some cases we'll have to create different keys for lines that are of the same type but meet other conditions
    else if (elementStyle.unindentFreshParagraphs) {
        // Check the previous line
        prevLine = [self.delegate.parser previousLine:line];
        if (prevLine.type != line.type) {
            type = type + 100;
        }
    }
    
    // RTL text lines also need to have a specific rule
    // if (hasRightToLeftText) type += 300;
    
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
    
    // Set default line height
    CGFloat lineHeight = styles.page.lineHeight;

    // Set element-based line height
    if (elementStyle.fontSize > 0 && elementStyle.fontSize > lineHeight) {
        lineHeight = elementStyle.fontSize;
    } else if (line.type == section) {
        BXFont* font = [self fontFamilyForLine:line];
        lineHeight = font.pointSize;
    }
    // Scale if needed
    lineHeight *= self.delegate.fonts.scale;
    
    style.minimumLineHeight = lineHeight;
    style.maximumLineHeight = lineHeight;
    
    style.lineHeightMultiple = (elementStyle.lineHeightMultiplier > 0) ? elementStyle.lineHeightMultiplier : styles.page.lineHeightMultiplier;
    style.lineHeightMultiple *= self.delegate.fonts.scale; // We need to multiply *multiplier* on mobile mode... sigh.
    style.alignment = elementStyle.textAlignment;

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
	} else if (type == subSection) {
		style.paragraphSpacingBefore = styles.page.lineHeight;
	} else if (type == section) {
		style.paragraphSpacingBefore = styles.page.lineHeight * 1.5;
	}
    
    // You *can* override these if you want to see forests burn and innocence drop from childrens' faces
    if (elementStyle.marginTop > 0) style.paragraphSpacingBefore = elementStyle.marginTop;
    if (elementStyle.marginBottom > 0) style.paragraphSpacing = elementStyle.marginBottom;
	
	_paragraphStyles[paperSizeKey][typeKey] = style;
	
	return style;
}

#pragma mark - Formatting shorthands

/// Forces reformatting of each line.
/// TODO: Move the cool initial formatting block here and make it OS-agnostic.
- (void)formatAllLines
{
    // Reset sizings
    self.paragraphStyles = NSMutableDictionary.new;

    for (Line* line in self.parser.lines) {
        @autoreleasepool {
            line.formattedAs = -1; // Force font change
            [self formatLine:line];
        }
    }

    [self.parser.changedIndices removeAllIndexes];
    [self.delegate ensureLayout];
}

/// Reformats all lines asynchronously
- (void)formatAllAsynchronously
{
    // Reset sizings
    self.paragraphStyles = NSMutableDictionary.new;
    [self processBatchFrom:0 batch:100];
}

- (void)processBatchFrom:(NSInteger)location batch:(NSInteger)batchSize
{
    if (location >= self.delegate.parser.lines.count) return;

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self formatLinesWithBatch:NSMakeRange(location, batchSize)];
        [self processBatchFrom:location+batchSize batch:batchSize];
    });
}

- (void)formatLinesWithBatch:(NSRange)range
{
    for (NSInteger i=0; i<range.length; i++) {
        NSInteger idx = range.location + i;
        if (idx >= self.delegate.parser.lines.count) break;
        
        Line* l = self.delegate.parser.lines[idx];
        l.formattedAs = -1;
        [self formatLine:l];
    }
}

/// Reapplies all paragraph styles
- (void)resetSizing
{
    self.paragraphStyles = nil;
    for (Line* line in self.parser.lines) {
        NSMutableParagraphStyle* pStyle = [self paragraphStyleFor:line];
        // Don't go over bounds
        NSRange range = (NSMaxRange(line.range) <= self.textStorage.length) ? line.range : line.textRange;
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

/// Forces reformatting of a range
- (void)forceFormatChangesInRange:(NSRange)range
{
    #if TARGET_OS_OSX
        [self.delegate.getTextView.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:range];
    #endif
    
    NSArray *lines = [self.delegate.parser linesInRange:range];
    for (Line* line in lines) {
        [self formatLine:line];
    }
}

- (void)reformatLinesAtIndices:(NSIndexSet*)indices
{
    [indices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        Line *line = self.parser.lines[idx];
        [self formatLine:line];
    }];
}


#pragma mark - Format a single line

/// Formats a single line in editor
- (void)formatLine:(Line*)line
{
	[self formatLine:line firstTime:NO];
}

/// Formats one line of screenplay.
/// - note To support ahead-of-time rendering, we are using `NSMutableAttributedString` in place of  `NSTextStorage`, even when referring to the actual text storage (which is basically just a mutable attributed string subclass)
- (void)formatLine:(Line*)line firstTime:(bool)firstTime
{ @autoreleasepool {
	// SAFETY MEASURES:
    // Don't do anything if the line is null or we don't have a text storage, and don't go out of range when attached to an editor
    if (line == nil || self.textStorage == nil || NSMaxRange(line.textRange) > self.textStorage.length) {
        self.lineBeingFormatted = nil;
        return;
    }
    
    _formatting = true;
    self.lineBeingFormatted = line; // Store the currently formatted line to fix iOS issues
    
	ThemeManager *themeManager = ThemeManager.sharedManager;
    NSMutableAttributedString *textStorage = self.textStorage;
    
    // Get editing status from delegate
    bool alreadyEditing = _delegate.textStorage.isEditing;
    if (!alreadyEditing) [textStorage beginEditing];
	
    NSRange selectedRange = _delegate.selectedRange;
	NSRange range = line.textRange; // range without line break
	NSRange fullRange = line.range; // range WITH line break
	if (NSMaxRange(fullRange) > textStorage.length) fullRange.length -= 1;

    // Check if we should force the font or not. If the current type is NOT the formatted type, we should always reset font.
	bool forceFont = (line.formattedAs != line.type);
			
	// Current attribute dictionary
	NSMutableDictionary* attributes;
	NSMutableDictionary* newAttributes = NSMutableDictionary.new;
    if (firstTime || line.position == self.textStorage.length) attributes = NSMutableDictionary.new;
    else {
        attributes = [textStorage attributesAtIndex:line.position longestEffectiveRange:nil inRange:line.textRange].mutableCopy;
    }
	
	// Remove some attributes so they won't get overwritten
	[attributes removeObjectForKey:BeatRevisions.attributeKey];
	[attributes removeObjectForKey:BeatReview.attributeKey];
	[attributes removeObjectForKey:BeatRepresentedLineKey];
    
	// Store the represented line
	NSRange representedRange;
	if (range.length > 0) {
		Line* representedLine = [textStorage attribute:BeatRepresentedLineKey atIndex:line.position longestEffectiveRange:&representedRange inRange:range];
		if (representedLine != line || representedRange.length != range.length) {
			[textStorage addAttribute:BeatRepresentedLineKey value:line range:fullRange];
		}
	} else {
		forceFont = true;
		newAttributes[BeatRepresentedLineKey] = line;
	}
		    
    // Foreground color
	if (attributes[NSForegroundColorAttributeName] == nil) {
		newAttributes[NSForegroundColorAttributeName] = themeManager.textColor;
	}
    
    // Do nothing else if formatting is disabled
    if (self.delegate.disableFormatting) {
        newAttributes[NSParagraphStyleAttributeName] = NSParagraphStyle.new;
        newAttributes[NSFontAttributeName] = self.fonts.regular;
        [textStorage addAttributes:newAttributes range:fullRange];
        if (!alreadyEditing) [textStorage endEditing];
        self.lineBeingFormatted = nil;
        _formatting = false;
        return;
    }
    
    // Create paragraph style
    NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:line];
    // Add to attributes if needed
    if (![attributes[NSParagraphStyleAttributeName] _equalTo:paragraphStyle]) {
        newAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    }
    
	// Do nothing for already formatted empty lines (except update the represented line)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0 &&
        line != _delegate.characterInputForLine && [paragraphStyle _equalTo:attributes[NSParagraphStyleAttributeName]]) {
		// If we need to update the represented line, do it here
		if (newAttributes[BeatRepresentedLineKey]) {
			[textStorage addAttribute:BeatRepresentedLineKey value:newAttributes[BeatRepresentedLineKey] range:fullRange];
		}
		if (!alreadyEditing) [textStorage endEditing];
        
        [_delegate.getTextView setTypingAttributes:attributes];
        
        self.lineBeingFormatted = nil;
        _formatting = false;
		return;
	}
    
	// Store the type we are formatting for
	line.formattedAs = line.type;
    
	// Extra rules for character cue input
	if (_delegate.characterInput && _delegate.characterInputForLine == line) {
		// Do some extra checks for dual dialogue
        if (line.length && line.string.lastNonWhiteSpaceCharacter == '^') line.type = dualDialogueCharacter;
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
            [self addAttribute:NSForegroundColorAttributeName value:themeManager.textColor range:line.range textStorage:nil];
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
        
	// Add new attributes
	NSRange attrRange = range;
	if (range.length == 0 && range.location < textStorage.string.length) {
		attrRange = NSMakeRange(range.location, range.length + 1);
	}
		
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	// If we are editing a dialogue block at the end of the document, the line will be empty.
	// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
    bool shouldSetTypingAttributes = false;
	if (!firstTime && line.string.length == 0 && NSLocationInRange(self.delegate.selectedRange.location, line.range)) {
		Line* previousLine;
		
        NSInteger lineIndex = [self.parser indexOfLine:line];
		if (lineIndex > 0 && lineIndex != NSNotFound) previousLine = [self.parser.lines objectAtIndex:lineIndex - 1];
		
		// Keep dialogue input after any dialogue elements
		if (previousLine.isDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dialogue];
		} else if (previousLine.isDualDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dualDialogue];
		} else {
			paragraphStyle = [self paragraphStyleFor:line];
		}
		
		attributes[NSParagraphStyleAttributeName] = paragraphStyle;
        newAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
        
        shouldSetTypingAttributes = true;
	} else {
		[attributes removeObjectForKey:NSParagraphStyleAttributeName];
	}
        
    // Apply formatting
    if (newAttributes.count) {
        [textStorage addAttributes:newAttributes range:attrRange];
    }
    
    // Apply inline formatting
	[self applyInlineFormatting:line reset:forceFont textStorage:textStorage];
    
    // Revised text colors
	[self revisedTextStyleForRange:range];
	
    // Actual text colors
	[self setTextColorFor:line];
    
    if (!alreadyEditing) [textStorage endEditing];
    if (shouldSetTypingAttributes) [_delegate.getTextView setTypingAttributes:attributes];
    
    self.lineBeingFormatted = nil;
    _formatting = false;
} }

- (void)applyInlineFormatting:(Line*)line reset:(bool)reset textStorage:(NSMutableAttributedString*)textStorage
{
    [BeatMeasure queue:@"format" startPhase:@"inline formatting"];
    RenderStyle* style = [self.delegate.editorStyles forLine:line];
    
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

	NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
	
	// Remove underline/strikeout
	[textStorage addAttribute:NSUnderlineStyleAttributeName value:@0 range:globalRange];
	[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:globalRange];

    [self applyTrait:0 range:line.textRange textStorage:textStorage];
    
    if (style.bold) [self applyTrait:BXBoldFontMask range:line.textRange textStorage:textStorage];
    if (style.italic) [self applyTrait:BXItalicFontMask range:line.textRange textStorage:textStorage];
    if (style.underline) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
	
    // Italic for note
    [line.noteRanges enumerateRangesInRange:range options:0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
        [self applyTrait:BXItalicFontMask range:globalRange textStorage:textStorage];
    }];
    
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
    // NSLayoutManager doesn't have traits on iOS. We need to do some trickery – and navigate around full width punctuation. I hate this.
    NSInteger maxLength = self.delegate.text.length;
    if (NSMaxRange(range) <= maxLength && range.location != maxLength) {
        NSRange fontRange = range;
        unichar firstChar = [textStorage.string characterAtIndex:range.location];
        bool fullWidthPunctuation = (firstChar >= 0xFF01 && firstChar <= 0xFF60);
        
        if (fullWidthPunctuation) {
            fontRange.location += 1;
            fontRange.length -= 1;
        }
        
        BXFont* font = [textStorage attribute:NSFontAttributeName atIndex:fontRange.location effectiveRange:nil];
        UIFontDescriptorSymbolicTraits traits = 0;
        
        if (mask_contains(trait, BXBoldFontMask)) traits |= UIFontDescriptorTraitBold;
        if (mask_contains(trait, BXItalicFontMask)) traits |= UIFontDescriptorTraitItalic;
        
        BXFont* newFont = [BeatFontSet fontWithTrait:traits font:font];
        [textStorage addAttribute:NSFontAttributeName value:newFont range:fontRange];
    }
#else
    // NSLayoutManager DOES have traits on macOS
	[textStorage applyFontTraits:trait range:range];
#endif
}


#pragma mark - Set font

- (BXFont* _Nonnull)fontFamilyForLine:(Line*)line
{
    [BeatMeasure queue:@"format" startPhase:@"font family"];
    BXFont* font = self.regular;
    
    RenderStyle* style = [self.delegate.editorStyles forLine:line];
    NSString* fontName = style.font;
        
    CGFloat scale = self.delegate.fontScale;
    if (scale <= 0.0) scale = 1.0;
    CGFloat fontSize = scale * ((style.fontSize > 0) ? style.fontSize : 12.0);
    
    if ((fontName != nil && fontName.length > 0)) {
        font = nil;
        
        if ([fontName isEqualToString:@"system"]) {
            font = [BXFont systemFontOfSize:fontSize];
        } else if ([fontName isEqualToString:@"default"]) {
            font = self.delegate.fonts.regular;
        } else if ([fontName isEqualToString:@"courier"]) {
            font = [BeatFontManager.shared fontsWith:BeatFontTypeFixed scale:scale].regular;
            font = [BXFont fontWithName:font.fontName size:fontSize];
        } else {
            font = [BXFont fontWithName:fontName size:fontSize];
        }
        
        if (font == nil) font = [BXFont fontWithName:self.delegate.fonts.regular.fontName size:fontSize];
    } else if (font != nil) {
        font = [BXFont fontWithName:font.fontName size:fontSize];
    }
        
    return (font != nil) ? font : self.regular;
    
    return font;
}

/// Sets the font for given line (if needed)
- (void)setFontForLine:(Line*)line {
    [self setFontForLine:line force:false];
}
/// Sets the font for given line. You can force it if needed.
- (void)setFontForLine:(Line*)line force:(bool)force {
    [BeatMeasure queue:@"format" startPhase:@"set font"];
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


#pragma mark - Set foreground color

- (void)setForegroundColor:(BXColor*)color line:(Line*)line range:(NSRange)localRange textStorage:(NSMutableAttributedString*)textStorage
{
    if (textStorage == nil) textStorage = self.textStorage;
    
	NSRange globalRange = [line globalRangeFromLocal:localRange];
	
	// Don't go out of range and add attributes
	if (NSMaxRange(localRange) <= line.string.length && localRange.location >= 0 && color != nil) {
        [self addAttribute:NSForegroundColorAttributeName value:color range:globalRange textStorage:textStorage];
	}
	
}

#pragma mark - Set attributes

/// Safely adds an attribute to the text. Set `textStorage` to `nil` to use the default editor text storage.
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range textStorage:(NSMutableAttributedString*)textStorage;
{
    if (textStorage == nil) textStorage = self.textStorage;
    
	// Don't go out of range
    if (NSMaxRange(range) >= textStorage.length) {
		range.length = textStorage.length - range.location;
        if (range.length <= 0 || NSMaxRange(range) > textStorage.length) return;
	}
	
	if (range.length > 0) [textStorage addAttribute:key value:value range:range];
}


#pragma mark - Text color

- (void)setTextColorFor:(Line*)line
{
    [self setTextColorFor:line textStorage:nil];
}

- (void)setTextColorFor:(Line*)line textStorage:(NSMutableAttributedString*)textStorage
{
    if (textStorage == nil) textStorage = self.textStorage;
    
	// Foreground color attributes
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
    // Any fully omitted text is just invisible
	if (line.omitted && !line.isNote) {
        [self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
		return;
	}
    
	// Set the base font color
    [self setForegroundColor:themeManager.textColor line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
	
	// Heading elements can be colorized using [[COLOR COLORNAME]],
	// so let's respect that first
	if (line.isOutlineElement || line.type == synopse) {
		BXColor *color;
		if (line.color.length > 0) {
			color = [BeatColors color:line.color];
		}
		if (color == nil) {
            if (line.type == heading) color = themeManager.headingColor;
			else if (line.type == section) color = themeManager.sectionTextColor;
			else if (line.type == synopse) color = themeManager.synopsisTextColor;
		}
		
        [self setForegroundColor:color line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
	}
	else if (line.type == pageBreak) {
        [self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
	}
    else if (line.isAnySortOfDialogue && self.delegate != nil) {
        BeatCharacterData* cd = [BeatCharacterData.alloc initWithDelegate:self.delegate];
        NSArray<Line*>* block = [self.delegate.parser blockFor:line];
        
        Line* cue = block.firstObject;
        NSString* chrName = cue.characterName;
        BeatCharacter* c = [cd getCharacterWith:chrName];
        
        if (c.highlightColor.length > 0) {
            BXColor* color = [BeatColors color:c.highlightColor];
            if (color != nil) {
                [self setForegroundColor:color line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
                
                // Make sure the whole block gets the correct color
                NSInteger idx = [self.delegate.parser indexOfLine:line];
                if (idx+1 < self.delegate.parser.lines.count) {
                    Line* nextLine = self.delegate.parser.lines[idx+1];
                    if (nextLine.isAnySortOfDialogue && nextLine.length > 0) [self.delegate.parser.changedIndices addIndex:idx+1];
                }
            }
        }
        
    }
		
	// Enumerate FORMATTING RANGES and make all of them invisible
	[line.formattingRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self setForegroundColor:themeManager.invisibleTextColor line:line range:range textStorage:textStorage];
	}];
	
	// Enumerate MACRO RANGES
	[line.macroRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self setForegroundColor:themeManager.macroColor line:line range:range textStorage:textStorage];
	}];
	
	NSArray* notes = line.noteData;
	for (BeatNoteData* note in notes) {
		NSRange range = note.range;
		BXColor* color = themeManager.commentColor;
		
        if (note.type == NoteTypePageNumber) {
            color = [BeatColors color:@"purple"];
        } else if (note.color) {
			BXColor* c = [BeatColors color:note.color];
			if (c != nil) color = c;
		}
		
        if (range.length > 0) [self setForegroundColor:color line:line range:range textStorage:textStorage];
	}
	
	// Enumerate title page ranges
	if (line.isTitlePage && line.titleRange.length > 0) {
        [self setForegroundColor:themeManager.commentColor line:line range:line.titleRange textStorage:textStorage];
	}
	
	// Bullets for forced empty lines are invisible, too
	else if ((line.string.containsOnlyWhitespace && line.length >= 2)) {
        [self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length) textStorage:textStorage];
	}
	
	// Color markers
	else if (line.markerRange.length) {
		BXColor *color;
				
		if (line.marker.length == 0) color = [BeatColors color:@"orange"];
		else color = [BeatColors color:line.marker];
		
		NSRange markerRange = line.markerRange;
		
        if (color) [self setForegroundColor:color line:line range:markerRange textStorage:textStorage];
	}
    
    [self revisedTextColorFor:line];
}

- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym
{
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

- (void)revisedTextStyleForRange:(NSRange)globalRange
{
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

- (void)revisedTextColorFor:(Line*)line
{
	if (![BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor]) return;
	
    NSMutableAttributedString *textStorage = self.textStorage;
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:line.textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
        NSString* colorName = BeatRevisions.revisionGenerations[revision.generationLevel].color;
        
		BXColor* color = BeatColors.colors[colorName];
		if (color == nil) return;
		
        [self addAttribute:NSForegroundColorAttributeName value:color range:range textStorage:textStorage];
	}];
}

- (void)refreshRevisionTextColors
{
    [self refreshRevisionTextColorsInRange:NSMakeRange(0, self.textStorage.length)];
}

- (void)refreshRevisionTextColorsInRange:(NSRange)range
{
	// First update revision attribute ranges
    [self revisedTextStyleForRange:range];
	
    // Then apply color for each line. This is very heavy but I don't know any other solution.
	NSArray* lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
        [self setTextColorFor:line];
	}
}

- (void)refreshTextColorsForTypes:(NSIndexSet*)types range:(NSRange)range
{

    NSArray* lines = [self.parser linesInRange:range];
    for (Line* line in lines) {
        if ([types containsIndex:line.type]) [self setTextColorFor:line];
    }
     
    /*
    NSArray<Line*>* lines = self.delegate.parser.lines.copy;
    
    @synchronized (self.delegate.getTextView.text) {
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
        dispatch_apply(lines.count, queue, ^(size_t i) {
            Line *line = lines[i];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self setTextColorFor:line];
            });
        });
        
        [self.delegate updateLayout];
        [self.delegate ensureLayout];
    }
     */
}


#pragma mark - Background refreshing

- (void)refreshBackgroundForRange:(NSRange)range
{
    NSArray *lines = [self.delegate.parser linesInRange:range];
    for (Line* line in lines) {
        [self refreshRevisionTextColorsInRange:line.textRange];
        [self.delegate.layoutManager invalidateDisplayForCharacterRange:line.textRange];
    }
}

- (void)refreshBackgroundForLine:(Line*)line clearFirst:(bool)clear
{
    [self.delegate.layoutManager invalidateDisplayForCharacterRange:line.textRange];
}

- (void)refreshBackgroundForAllLines
{
    NSArray* lines = self.delegate.parser.lines;
    for (Line* line in lines) {
        [self refreshRevisionTextColorsInRange:line.textRange];
        [self.delegate.layoutManager invalidateDisplayForCharacterRange:line.textRange];
    }
}


@end

/*
 
 takana on eteenpäin
 lautturi meitä odottaa
 tämä joki
 se upottaa
 
 */
