//
//  BeatPaginationBlock.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2-Swift.h>

#import "BeatPaginationBlock.h"
#import "BeatPagination.h"
#import "BeatPageBreak.h"

@interface BeatPaginationBlock ()
@property (nonatomic) CGFloat calculatedHeight;
@property (nonatomic) NSArray<NSUUID*>* UUIDs;

@property (nonatomic) NSMutableDictionary<NSUUID*, NSNumber*>* lineHeights;

@end

@implementation BeatPaginationBlock

+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate {
	return [BeatPaginationBlock.alloc initWithLines:lines delegate:delegate isDualDialogueElement:false];
}
+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement {
	return [BeatPaginationBlock.alloc initWithLines:lines delegate:delegate isDualDialogueElement:dualDialogueElement];
}

- (instancetype)initWithLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement {
	self = [super init];
	if (self) {
		_delegate = delegate;
		
		_calculatedHeight = -1.0;
		
		_lines = lines;
		_dualDialogueElement = dualDialogueElement;
		
		if (!_dualDialogueElement) {
			Line* firstLine = _lines.firstObject;
			if (firstLine.nextElementIsDualDialogue) _dualDialogueContainer = true;
		}
	}
	return self;
}

/// Returns the type for first line in the block.
- (LineType)type {
	return self.lines.firstObject.type;
}

/// Returns the full height of block, **including** top margin when applicable.
- (CGFloat)height
{
	if (_calculatedHeight > 0.0) return _calculatedHeight;
	
    BeatExportSettings* settings = self.delegate.settings;
    
	CGFloat height = 0.0;
	if (self.dualDialogueContainer) {
		CGFloat leftHeight = self.leftColumnBlock.height;
		CGFloat rightHeight = self.rightColumnBlock.height;
		
		if (leftHeight >= rightHeight) height = leftHeight;
		else height = rightHeight;
	} else {
		for (Line* line in self.lines) {
			if (line.isInvisible && !([settings.additionalTypes containsIndex:line.type] ||
                                     (line.note && settings.printNotes)
                                     )) continue;
			CGFloat lineHeight = [self heightForLine:line];
			height += lineHeight;
		}
	}
	
	_calculatedHeight = height;
	return height;
}

/// Returns the height (in points) for given line in block.
- (CGFloat)heightForLine:(Line*)line
{
	// We'll cache the line heights in a dictionary by UUID
	if (self.lineHeights == nil) self.lineHeights = NSMutableDictionary.new;

	// If the height has already been calculated, return the result
	if (self.lineHeights[line.uuid] != nil) {
		return self.lineHeights[line.uuid].floatValue;
	}
    
    // Page breaks have 0 height
    if (line.type == pageBreak) return 0.0;
    
    // If this is a *dual dialogue column*, we'll need to convert the style.
    LineType type = line.type;
    if (self.dualDialogueElement) {
        if (type == dialogue) type = dualDialogue;
        else if (type == character) type = dualDialogueCharacter;
        else if (type == dualDialogueParenthetical) type = dualDialogueParenthetical;
    }

    BeatPaperSize pageSize = self.delegate.settings.paperSize;
    
    // Get render style
    RenderStyle *style = [self.delegate.styles forLine:line];
    CGFloat topMargin = (line.canBeSplitParagraph && !line.beginsNewParagraph) ? 0.0 : style.marginTop;
    
	// Create a bare-bones paragraph style
	NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
    CGFloat lineHeight = (self.delegate.styles.page.lineHeight >= 0) ? self.delegate.styles.page.lineHeight : BeatPagination.lineHeight;
    
    pStyle.minimumLineHeight    = lineHeight;
	pStyle.maximumLineHeight    = lineHeight;
    pStyle.firstLineHeadIndent  = style.firstLineIndent;
    pStyle.headIndent           = style.indent;

        
    // Set font for this element
    BXFont* font = _delegate.fonts.regular;
    if (style.font) font = [self fontFor:style];

    NSString* stringWithoutFormatting = [line stripFormattingWithSettings:self.delegate.settings];
    NSAttributedString* string = [NSMutableAttributedString.alloc initWithString:stringWithoutFormatting attributes:@{
        NSFontAttributeName: font,
        NSParagraphStyleAttributeName: pStyle
    }];


	// Calculate the line height
    CGFloat width = [style widthWithPageSize:pageSize];
    if (width == 0.0) width = [self.delegate.styles.page defaultWidthWithPageSize:pageSize];
	
    CGFloat height = 0.0;
    height = [string heightWithContainerWidth:width] + topMargin;
		
	// Save the calculated top margin for full block if this is the first element on page, AND this behavior isn't overridden
    if (line == self.lines.firstObject && ![self.delegate.styles forLine:line].forcedMargin) {
        self.topMargin = topMargin;
    }
	
	self.lineHeights[line.uuid] = [NSNumber numberWithFloat:height];
	return height;
}

- (BXFont*)fontFor:(RenderStyle*)style
{
    BXFont* font;
    
    if ([style.font isEqualToString:@"system"]) {
        BXFontDescriptorSymbolicTraits traits = 0;
        if (style.italic) traits |= BXFontDescriptorTraitItalic;
        if (style.bold) traits |= BXFontDescriptorTraitBold;
        
        CGFloat size = (style.fontSize > 0) ? style.fontSize : 11.0;
        font = [BeatFonts fontWithTrait:traits font:[BXFont systemFontOfSize:size]];
    }
    
    if (font == nil) font = _delegate.fonts.regular;
    
    return font;
}

/// Returns the line which resides at given Y coordinate within the local height of this block.
- (Line*)lineAt:(CGFloat)y {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		height += [self heightForLine:line];
		if (height >= y) return line;
	}
	
	return nil;
}

/// Returns the height of preceding elements until the given line.
- (CGFloat)heightUntil:(Line*)lineToFind {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		if (line == lineToFind) {
			return height;
		}
		
		height += [self heightForLine:line];
	}
	
	return 0.0;
}

/// Returns the line which doesn't fit within the given remaining space.
- (Line*)findSpillerAt:(CGFloat)remainingSpace {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		height += [self heightForLine:line];
		
		if (height >= remainingSpace) {
			return line;
		}
	}
	
	return nil;
}


#pragma mark - Return left/right columns for dual dialogue

/// Returns lines for the left column of a dual dialogue block
- (NSArray<Line*>*)leftSideDialogue {
	NSMutableArray *lines = NSMutableArray.new;
	for (Line* line in self.lines) {
		if (line.type == dualDialogueCharacter) break;
		[lines addObject:line];
	}
	return lines;
}
/// Returns lines for the right side of a dual dialogue block
- (NSArray<Line*>*)rightSideDialogue {
	NSMutableArray *lines = NSMutableArray.new;
	for (Line* line in self.lines) {
		if (line.isDialogue) continue;
		[lines addObject:line];
	}
	return lines;
}

/// Returns (and when needed, creates) a dual dialogue block inside this block.
- (BeatPaginationBlock*)leftColumnBlock {
	if (_leftColumnBlock == nil) {
		_leftColumnBlock = [BeatPaginationBlock.alloc initWithLines:[self leftSideDialogue] delegate:self.delegate isDualDialogueElement:true];
	}
	return _leftColumnBlock;
}

/// Returns (and when needed, creates) a dual dialogue block inside this block.
- (BeatPaginationBlock*)rightColumnBlock {
	if (_rightColumnBlock == nil) {
		_rightColumnBlock = [BeatPaginationBlock.alloc initWithLines:[self rightSideDialogue] delegate:self.delegate isDualDialogueElement:true];
	}
	return _rightColumnBlock;
}


#pragma mark - Breaking block across pages

/// Returns the indexes in which this block *could* be broken apart. Basically useless for anything else than dialogue at this point.
- (NSIndexSet*)possiblePageBreakIndices {
	// For every non-dialogue block, we'll just return 0
	Line* firstLine = self.lines.firstObject;
	if (!firstLine.isAnyCharacter) {
		return [NSIndexSet indexSetWithIndex:0];
	}

	NSMutableIndexSet* indices = [NSMutableIndexSet indexSetWithIndex:0];
	for (NSInteger i=0; i<self.lines.count; i++) {
		Line *line = _lines[i];
		
        // Any parenthetical after the first one are good places to break the page
        if (line.isAnyParenthetical && i > 1) [indices addIndex:i];
        // Any line of dialogue is a good place to attempt to break the page
        if (line.isAnyDialogue) [indices addIndex:i];
	}
	
	return indices;
}

/// Used to check if this block can be split across pages at all.
- (NSInteger)pageBreakIndexWithRemainingSpace:(CGFloat)remainingSpace {
	NSIndexSet *indices = [self possiblePageBreakIndices];
	
	Line* line = [self findSpillerAt:remainingSpace];
	NSInteger idx = [self.lines indexOfObject:line];
	
	if (line == nil || idx == NSNotFound) {
		return NSNotFound;
	}
	
	return [indices indexLessThanOrEqualToIndex:idx];
}

/**
 - returns an array with `onCurrentPage[Line], onNextPage[Line], BeatPageBreak`
 */
-(NSArray*)breakBlockWithRemainingSpace:(CGFloat)remainingSpace {
	// Dual dialogue requires different logic
	if (self.dualDialogueContainer) {
		return [self splitDualDialogueWithRemainingSpace:remainingSpace];
	}
    
	NSInteger pageBreakIndex = [self pageBreakIndexWithRemainingSpace:remainingSpace];
    if (pageBreakIndex == NSNotFound) {
        // First catch weird edge cases
        //BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:self.lines.firstObject lineHeight:self.delegate.styles.page.lineHeight reason:@"No page break index found"];
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"No page break index found"];
		return @[@[], self.lines, pageBreak];
    }
    
    // Then, let's handle the real stuff. The sub-methods return the same array as documented above: lines remaining, lines broken to next page, page break data.
    NSArray* pageBreakData;
    
    // First find a spiller
    Line* spiller = [self findSpillerAt:remainingSpace];
    
    if (spiller.type == action) {
        // Break action paragraphs into two if possible and feasible
        pageBreakData = [self splitParagraphWithRemainingSpace:remainingSpace];
    } else if (spiller.isDialogueElement || spiller.isDualDialogueElement) {
        // Break apart dialogue blocks
        pageBreakData = [self splitDialogueAt:spiller remainingSpace:remainingSpace];
    } else {
        // This is something else (like lyrics, transition, whatever, let's just split it at beginning)
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"No page break index found"];
        pageBreakData = @[@[], self.lines, pageBreak];
    }
    
    return pageBreakData;
}

- (NSArray*)splitParagraphWithRemainingSpace:(CGFloat)remainingSpace {
	Line *line = self.lines.firstObject;
	NSString *str = [line stripFormattingWithSettings:self.delegate.settings];
	NSString *retain = @"";

    BeatPaperSize paperSize = self.delegate.settings.paperSize;
    
    // Get block size
	RenderStyle *style = [self.delegate.styles forLine:line];
    CGFloat width = [style widthWithPageSize:paperSize];
    if (width == 0.0) width = [self.delegate.styles.page defaultWidthWithPageSize:paperSize];
	
	// Create the layout manager for remaining space calculation
    NSLayoutManager *lm = [self layoutManagerForString:str line:line];
	
	// We'll get the number of lines rather than calculating exact size in NSTextField
	__block NSInteger numberOfLines = 0;
	
	// Iterate through line fragments
	__block CGFloat pageBreakPos = 0;
	__block NSInteger length = 0;
    CGFloat lineHeight = (self.delegate.styles.page.lineHeight >= 0) ? self.delegate.styles.page.lineHeight : BeatPagination.lineHeight;
    
	[lm enumerateLineFragmentsForGlyphRange:NSMakeRange(0, lm.numberOfGlyphs) usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		numberOfLines++;
		if (numberOfLines < remainingSpace / lineHeight) {
			NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
			length += charRange.length;
			pageBreakPos = numberOfLines * lineHeight;
		} else {
			*stop = true;
		}
	}];
		
	retain = [str substringToIndex:length];
	
	NSArray *splitElements = [line splitAndFormatToFountainAt:retain.length];
	Line *prePageBreak = splitElements[0];
	Line *postPageBreak = splitElements[1];
	
    NSArray* onNextPage = (postPageBreak.length > 0) ? @[postPageBreak] : @[];
        
	//BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:pageBreakPos element:line lineHeight:self.delegate.styles.page.lineHeight reason:@"Paragraph split"];
    BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:retain.length element:line attributedString:[line attributedStringForOutputWith:_delegate.settings] reason:@"Paragraph split"];
	return @[@[prePageBreak], onNextPage, pageBreak];
}

- (NSArray*)splitDualDialogueWithRemainingSpace:(CGFloat)remainingSpace {
	NSArray *left = self.leftSideDialogue;
	NSArray *right = self.rightSideDialogue;
	
	BeatPaginationBlock *leftBlock = [BeatPaginationBlock.alloc initWithLines:left delegate:_delegate isDualDialogueElement:true];
	BeatPaginationBlock *rightBlock = [BeatPaginationBlock.alloc initWithLines:right delegate:_delegate isDualDialogueElement:true];
	
	NSMutableArray *onThisPage = NSMutableArray.new;
	NSMutableArray *onNextPage = NSMutableArray.new;
	
	NSArray* leftResult;
	NSArray* rightResult;
	
	if (leftBlock.height > remainingSpace) {
		// We need to split left side
		leftResult = [leftBlock breakBlockWithRemainingSpace:remainingSpace];
		[onThisPage addObjectsFromArray:leftResult[0]];
		[onNextPage addObjectsFromArray:leftResult[1]];
	}
	if (rightBlock.height > remainingSpace) {
		// We need to split left side
		rightResult = [rightBlock breakBlockWithRemainingSpace:remainingSpace];
		[onThisPage addObjectsFromArray:rightResult[0]];
		[onNextPage addObjectsFromArray:rightResult[1]];
	}
	
	if (((NSArray*)leftResult[0]).count > 0 && ((NSArray*)rightResult[0]).count > 0) {
		return @[onThisPage, onNextPage, rightResult[2]];
	}
	
	//BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:self.lines.firstObject lineHeight:self.delegate.styles.page.lineHeight reason:@"Nothing was left on page with dual dialogue container"];
    BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"Nothing was left on page with dual dialogue container"];
	return @[@[], self.lines, pageBreak];
}

/// Splits a **block** of dialogue, retaining as much as possible in given remaining space.
- (NSArray*)splitDialogueAt:(Line*)spiller remainingSpace:(CGFloat)remainingSpace {
    //remainingSpace -= BeatPagination.lineHeight; // Make space for (MORE) etc.
    
    NSMutableArray* dialogueBlock = self.lines.mutableCopy;
    NSMutableArray<Line*>* onThisPage = NSMutableArray.new;
    NSMutableArray<Line*>* onNextPage = NSMutableArray.new;
    
    NSMutableArray<Line*>* tmpThisPage = NSMutableArray.new;
    NSMutableArray<Line*>* tmpNextPage = NSMutableArray.new;
    
    BeatPageBreak *pageBreak;
    Line* pageBreakItem;        // The element where we'll cut
    NSInteger cutoff = 0;       // Index at which we'll cut the dialogue in two
    
    // Find out where we can split the block
    NSIndexSet* splittableIndices = [self possiblePageBreakIndices];
        
    NSMutableArray* safeLines = NSMutableArray.new;
    
    // Iterate through elements in dialogue block and see where we no longer can fit anything on page
    for (NSInteger i=1; i<dialogueBlock.count; i++) {
        Line* line = dialogueBlock[i];
        
        CGFloat heightBefore = [self heightUntil:line];
        CGFloat h = heightBefore + [self heightForLine:line];
        
        // This line fits, handle it
        if (h <= remainingSpace) {
            if ((line.isAnyDialogue && i > 0) || line == dialogueBlock.lastObject) {
                // We got to the end of block safely
                [onThisPage addObjectsFromArray:safeLines];
                [onThisPage addObject:line];
                
                [safeLines removeAllObjects];
            } else {
                [safeLines addObject:line];
            }
            
            continue;
        }
        
        // This line doesn't. Let's find out how to split the block.
        if (line.isAnyParenthetical) {
            if ([splittableIndices containsIndex:i]) {
                // After a parenthetical which is NOT the second line, we'll just hop onto next page
                cutoff = i;
                pageBreakItem = line;
            } else {
                // This is the first item. We'll just toss the whole block onto the next page.
                cutoff = 1;
                pageBreakItem = dialogueBlock.firstObject;
            }
            
            break;
        } else if (line.isAnyDialogue) {
            // We'll try and split the dialogue line in two, if it's possible.
            NSArray* splitLine = [self splitDialogueLine:line remainingSpace:remainingSpace - heightBefore];
            Line* retain = splitLine[0];
            Line* split = splitLine[1];
        
            // Something was left on this page
            if (retain.length > 0) {
                cutoff = i + 1;
                [tmpThisPage addObjectsFromArray:safeLines];
                [tmpThisPage addObject:retain];
                
                pageBreak = splitLine[2];
            }
            
            // Something was cut off to next page
            if (split.length > 0 && retain.length > 0) {
                [tmpNextPage addObject:split];
            }
            // Nothing was left on current page, we'll need to see if we
            // actually can split the dialogue block here
            else if (retain.length == 0 && split.length > 0 && [splittableIndices containsIndex:i]) {
                cutoff = i;
                
                // Set the correct page break item
                pageBreakItem = split;
                
                // Add remaining safe lines
                [tmpNextPage insertObjects:safeLines atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, safeLines.count)]];
            }
            break;
        }
    }

    // We'll cut off at 0, so make page break item the first object in array
    if (cutoff == 0) pageBreakItem = self.lines.firstObject;
        
    [onThisPage addObjectsFromArray:tmpThisPage];
    [onNextPage addObjectsFromArray:tmpNextPage];
    [onNextPage addObjectsFromArray:[self.lines subarrayWithRange:NSMakeRange(cutoff, self.lines.count - cutoff)]];
    
    // Add character cues
    if (onThisPage.count && onNextPage.count) {
        [onThisPage insertObject:self.lines.firstObject atIndex:0];
        [onThisPage addObject:[self.delegate moreLineFor:self.lines.firstObject]];
        
        Line* cue = [self.delegate contdLineFor:self.lines.firstObject];
        [onNextPage insertObject:cue atIndex:0];
    }
    else if (onThisPage.count) {
        [onThisPage insertObject:self.lines.firstObject atIndex:0];
    }
    else {
        [onNextPage insertObject:self.lines.firstObject atIndex:0];
    }
    
    if (pageBreak == nil) {
        // Get page break index. If it's below 2 (or not found), make the first item be the page break.
        NSInteger pageBreakIndex = [self.lines indexOfObject:pageBreakItem];
        if ((pageBreakIndex == NSNotFound || pageBreakIndex <= 1) && onThisPage.count == 0) pageBreakItem = self.lines.firstObject;
    
        //pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:pageBreakItem lineHeight:self.delegate.styles.page.lineHeight];
        pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:pageBreakItem attributedString:nil reason:@"Dialogue cut"];
    }
    
    return @[ onThisPage, onNextPage, pageBreak ];
}


/// Splits a line of dialogue, retaining as much as possible in given remaining space.
- (NSArray*)splitDialogueLine:(Line*)line remainingSpace:(CGFloat)remainingSpace {
	// Regex for splitting into sentences
    NSRegularExpression* regex = [NSRegularExpression.alloc initWithPattern:@"(.+?[\\.\\?\\!…]+\\s*)" options:0 error:nil];
    
    // Create temporary string and atch sentences
    NSString* string = [line stripFormattingWithSettings:self.delegate.settings];
	NSArray* matches = [regex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
	
	NSMutableArray<NSString*>* sentences = NSMutableArray.new;
	NSInteger length = 0;
	
    // Break into sentences.
    for (NSTextCheckingResult *match in matches) {
        NSString *str = [string substringWithRange:match.range];
        length += str.length;
        
        [sentences addObject:str];
    }
    	
	// Make sure we're not missing anything, and if we are, bring it with us.
	if (length < string.length) {
		NSString *str = [string substringWithRange:NSMakeRange(length, string.length - length)];
		[sentences addObject:str];
	}

    // A fallback if we are paginating something that isn't really split into sentences.
    // Let's split it in words in that case.
    NSInteger firstSentenceHeight = [self heightForString:sentences.firstObject lineType:line.type];
    if ((CGFloat)firstSentenceHeight > self.delegate.maxPageHeight - self.delegate.styles.page.lineHeight * 2) {
        sentences = [string componentsSeparatedByString:@" "].mutableCopy;
    }
    
	NSMutableString* text = NSMutableString.new;
	NSInteger breakLength = 0;
	CGFloat breakPosition = 0.0;

    // Next, let's find out how much we can fit on this page
	for (NSString *sentence in sentences) { @autoreleasepool {
		[text appendString:sentence];
		CGFloat h = [self heightForString:text lineType:line.type];
		
		if (h < remainingSpace) {
			breakLength += sentence.length;
			breakPosition += h;
		} else {
			break;
		}
	} }
    
	NSArray *p = [line splitAndFormatToFountainAt:breakLength];
    BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:breakLength element:line attributedString:[line attributedStringForOutputWith:_delegate.settings] reason:@"Break paragraph"];
    
	return @[p[0], p[1], pageBreak];
}

/// Returns the height of string for given line type.
/// - note: This method doesn't take margins or any other styles into account, just the width.
/// TODO: WHAT THE FUCK IS THIS, please conform to new stylesheet standards
- (NSInteger)heightForString:(NSString *)string lineType:(LineType)type
{
	// This method MIGHT NOT work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	
    CGFloat lineHeight = (self.delegate.styles.page.lineHeight >= 0) ? self.delegate.styles.page.lineHeight : BeatPagination.lineHeight;
	if (string.length == 0) return lineHeight;
	
	// If this is a *dual dialogue* column, we'll need to convert the style.
	if (self.dualDialogueElement && (type == dialogue || type == character || type == parenthetical)) {
		if (type == dialogue) type = dualDialogue;
		else if (type == character) type = dualDialogueCharacter;
		else if (type == dualDialogueParenthetical) type = dualDialogueParenthetical;
	}
	
	BXFont* font = self.delegate.fonts.regular;
	RenderStyle *style = [self.delegate.styles forElement:[Line typeName:type]];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
    // BTW, why are we doing this? Is this a mistake?
	// font = [font fontWithSize:font.pointSize * 0.8];
#endif
	
    // Create paragraph style
    NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
    pStyle.minimumLineHeight = lineHeight;
    pStyle.maximumLineHeight = lineHeight;
    
	// set up the layout manager
	NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:string attributes:@{
        NSFontAttributeName: font,
        NSParagraphStyleAttributeName: pStyle
    }];
	NSLayoutManager *layoutManager = NSLayoutManager.new;
	
	NSTextContainer *textContainer = NSTextContainer.new;
	[textContainer setSize:CGSizeMake(width, MAXFLOAT)];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0];
	[layoutManager glyphRangeForTextContainer:textContainer];
	
	// We'll get the number of lines rather than calculating exact size in NSTextField
	NSInteger numberOfLines;
	NSInteger index;
	NSInteger numberOfGlyphs = layoutManager.numberOfGlyphs;
	
	// Iterate through line fragments
	NSRange lineRange;
	for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
		[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		index = NSMaxRange(lineRange);
	}
    	
	return numberOfLines * lineHeight;
}

/// Returns a layout manager for a string with given type. You can use this layout manager to for quick and dirty height calculation.
- (NSLayoutManager*)layoutManagerForString:(NSString*)string line:(Line*)line
{
    LineType type = line.type;
    
    // If this is a *dual dialogue* column, we'll need to convert the style.
    if (self.dualDialogueElement && (type == dialogue || type == character || type == parenthetical)) {
        if (type == dialogue) type = dualDialogue;
        else if (type == character) type = dualDialogueCharacter;
        else if (type == dualDialogueParenthetical) type = dualDialogueParenthetical;
    }
    
    RenderStyle *style = [self.delegate.styles forLine:line];
    
    BXFont* font = _delegate.fonts.regular;
    if (style.font) font = [self fontFor:style];
    
    BeatPaperSize paperSize = self.delegate.settings.paperSize;
    CGFloat width = [style widthWithPageSize:paperSize];
    if (width == 0.0) width = [self.delegate.styles.page defaultWidthWithPageSize:paperSize];
    
    NSParagraphStyle* pStyle = [self.delegate paragraphStyleFor:line];
    
#if TARGET_OS_IOS
    // Set font size to 80% on iOS
    // font = [font fontWithSize:font.pointSize * 0.8];
#endif
    
    // set up the layout manager
    NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{
        NSFontAttributeName: font,
        NSParagraphStyleAttributeName: pStyle
    }];
    NSLayoutManager *layoutManager = NSLayoutManager.new;
    
    NSTextContainer *textContainer = NSTextContainer.new;
    [textContainer setSize:CGSizeMake(width, MAXFLOAT)];
    
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [textContainer setLineFragmentPadding:0];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    // Perform layout
    [layoutManager numberOfGlyphs];
    
    return layoutManager;
}


#pragma mark - Rendering blocks to attributed strings

- (NSAttributedString*)attributedString {
	return [self attributedStringForFirstElement:false];
}
- (NSAttributedString*)attributedStringForFirstElementOnPage {
	return [self attributedStringForFirstElement:true];
}

/// Renders an attributed string for the whole block. Result is cached and won't be rendered again.
- (NSAttributedString*)attributedStringForFirstElement:(bool)isFirstElement {
	if (_delegate.renderer == nil) {
		NSLog(@"WARNING: No renderer specified for paginator. Returning empty string for block.");
	}
	return [_delegate.renderer renderBlock:self firstElementOnPage:isFirstElement];
}

- (CGFloat)widthFor:(Line*)line
{
    return [self widthForType:line.typeName];
}
- (CGFloat)widthForType:(NSString*)typeName
{
    RenderStyle* style = [_delegate.styles forElement:typeName];
    CGFloat width = [style widthWithPageSize:_delegate.settings.paperSize];
    if (width == 0.0) width = [_delegate.styles.page defaultWidthWithPageSize:_delegate.settings.paperSize];
    
    return width;
}

#pragma mark - Convenience

/// Returns an array of line UUIDs
- (NSArray<NSUUID*>*)UUIDs {
	if (_UUIDs == nil) {
        NSMutableArray* UUIDs = [NSMutableArray arrayWithCapacity:self.lines.count];
		for (Line* line in self.lines) {
			[UUIDs addObject:line.uuid];
		}
		_UUIDs = UUIDs;
	}
	
	return _UUIDs;
}

/// Checks if the block contains given line.
/// - note: This method uses UUIDs to match the lines in paginated (and cloned) content to those originally in parser.
- (bool)containsLine:(Line*)line {
	return [self.UUIDs containsObject:line.uuid];
}

@end
