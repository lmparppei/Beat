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

- (BeatPaginationBlock*)copyWithDelegate:(id<BeatPageDelegate>)delegate
{
    BeatPaginationBlock* block = [BeatPaginationBlock withLines:self.lines.copy delegate:self.delegate isDualDialogueElement:_dualDialogueElement];
    block.calculatedHeight = self.calculatedHeight;
    block.UUIDs = self.UUIDs.copy;
    block.lineHeights = self.lineHeights.mutableCopy;
    
    return block;
}

- (instancetype)initWithLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement {
	self = [super init];
	if (self) {
		_delegate = delegate;
		
		_lines = lines;
		_dualDialogueElement = dualDialogueElement;
        _calculatedHeight = -1.0;

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
            // This is not beautiful or elegant. Sorry.
			if (line.isInvisible && !([settings.additionalTypes containsIndex:line.type] ||
                                     (line.isNote && settings.printNotes)
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
    
    // Empty character cues have 0 height + margin
    if (line.isAnyCharacter && line.string.trim.length == 1 && line.numberOfPrecedingFormattingCharacters == 1) {
        return topMargin;
    }
    
	// Create a bare-bones paragraph style
	NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
    CGFloat lineHeight = (self.delegate.styles.page.lineHeight >= 0) ? self.delegate.styles.page.lineHeight : BeatPagination.lineHeight;
    
    pStyle.minimumLineHeight    = lineHeight;
	pStyle.maximumLineHeight    = lineHeight;
    pStyle.firstLineHeadIndent  = style.firstLineIndent;
    pStyle.headIndent           = style.indent;

        
    // Set font for this element. Make sure we won't encounter a nil value.
    BXFont* font = (_delegate.fonts.regular) ? _delegate.fonts.regular : BeatFontManager.shared.defaultFonts.regular;
    if (style.font) {
        BXFont* customFont = [self fontFor:style];
        if (customFont != nil) font = customFont;
    }
    
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
        font = [BeatFontSet fontWithTrait:traits font:[BXFont systemFontOfSize:size]];
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
	// Dialogue blocks have different types of safe indices
    Line* firstLine = self.lines.firstObject;
	if (firstLine.isAnyCharacter) return [self possiblePageBreakIndicesForDialogueBlock];

    NSMutableIndexSet* indices = NSMutableIndexSet.new;
    
    Line* previousLine = nil;
    for (NSInteger i=0; i<self.lines.count; i++) {
        Line* l = self.lines[i];
        
        bool unsafe = (previousLine.type == section || previousLine.type == heading || previousLine.type == shot);
        if (!unsafe) [indices addIndex:i];
        
        previousLine = l;
    }
    
	return indices;
}

- (NSIndexSet*)possiblePageBreakIndicesForDialogueBlock
{
    NSMutableIndexSet* indices = [NSMutableIndexSet indexSetWithIndex:0];
    
    for (NSInteger i=0; i<self.lines.count; i++) {
        Line* line = _lines[i];
        Line* previousLine = (i > 0) ? _lines[i-1] : nil;
        
        // Any parenthetical after a character cue one are good places to break the page.
        if (line.isAnyParenthetical && i > 1 && !previousLine.isAnyCharacter) [indices addIndex:i];
        // Any line of dialogue or a deeper dual dialogue character cue is a good place to attempt to break the page
        else if (line.isAnyDialogue || (line.type == dualDialogueCharacter && i > 0)) [indices addIndex:i];
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
 - returns an array with members `leftOnCurrentPage:[Line], onNextPage:[Line], BeatPageBreak`
 */
-(NSArray*)breakBlockWithRemainingSpace:(CGFloat)remainingSpace
{
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
    
    if (spiller.type == action || spiller.type == synopse || spiller.type == section || spiller.type == centered || spiller.type == lyrics || spiller.type == transitionLine) {
        // Break action paragraphs into two if possible and feasible
        pageBreakData = [self splitParagraphWithRemainingSpace:remainingSpace];
    } else if (spiller.isDialogue || spiller.isDualDialogue) {
        // Break apart dialogue blocks
        pageBreakData = [self splitDialogueAt:spiller remainingSpace:remainingSpace];
    } else if (pageBreakIndex > 0) {
        // Centered or lyrics, split at given safe index
        // TODO: This is dangerous, if we happen to have a very long lyrics / centered block. Add a failsafe!!!
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:pageBreakIndex element:spiller attributedString:nil reason:@"Multi-line block"];
        NSArray* thisPage = [self.lines subarrayWithRange:NSMakeRange(0, pageBreakIndex)];
        NSArray* nextPage = [self.lines subarrayWithRange:NSMakeRange(pageBreakIndex, self.lines.count - pageBreakIndex)];
        pageBreakData = @[thisPage, nextPage, pageBreak];
    } else {
        // This is something else (let's just split it at beginning)
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"No page break index found"];
        pageBreakData = @[@[], self.lines, pageBreak];
    }
    
    return pageBreakData;
}

- (NSArray*)splitParagraphWithRemainingSpace:(CGFloat)remainingSpace {
    return [self splitParagraphWithRemainingSpace:remainingSpace line:nil];
}

- (NSInteger)getOverflowLength:(Line *)line lineHeight:(CGFloat)lineHeight remainingSpace:(CGFloat)remainingSpace string:(NSString *)str {
    // For some reason we need to retain the text storage like this after macOS Sonoma. No idea why.
    NSTextStorage* textStorage;
    NSLayoutManager *lm = [self layoutManagerForString:str line:line textStorage:&textStorage];
    NSRange layoutRange = NSMakeRange(0, lm.numberOfGlyphs);
    
    // We'll get the number of lines rather than calculating exact size in NSTextField
    __block NSInteger numberOfLines = 0;
    __block CGFloat pageBreakPos = 0;
    __block NSInteger length = 0;
    
    [lm enumerateLineFragmentsForGlyphRange:layoutRange usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        numberOfLines++;
        
        if (numberOfLines < remainingSpace / lineHeight) {
            NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
            length += charRange.length;
            pageBreakPos = numberOfLines * lineHeight;
        } else {
            *stop = true;
        }
    }];
    return length;
}

- (CGFloat)getFullHeight:(Line *)line lineHeight:(CGFloat)lineHeight remainingSpace:(CGFloat)remainingSpace string:(NSString *)str numberOfLines:(NSInteger*)actualNumberOfLines
{
    // For some reason we need to retain the text storage like this after macOS Sonoma. No idea why.
    NSTextStorage* textStorage;
    NSLayoutManager *lm = [self layoutManagerForString:str line:line textStorage:&textStorage];
    NSRange layoutRange = NSMakeRange(0, lm.numberOfGlyphs);
    
    // We'll get the number of lines rather than calculating exact size in NSTextField
    __block NSInteger numberOfLines = 0;
    __block NSInteger length = 0;
    
    [lm enumerateLineFragmentsForGlyphRange:layoutRange usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        numberOfLines++;
        
        NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
        length += charRange.length;
    }];
    
    *actualNumberOfLines = numberOfLines;
    return length;
}

- (NSArray*)splitParagraphWithRemainingSpace:(CGFloat)remainingSpace line:(Line*)line
{
    // If no line is set, let's use the first item
    if (line == nil) line = self.lines.firstObject;
    
    BeatParagraphPaginationMode mode = self.delegate.paragraphPaginationMode;
    
    // Line height and render style for this element
    CGFloat lineHeight = (self.delegate.styles.page.lineHeight >= 0) ? self.delegate.styles.page.lineHeight : BeatPagination.lineHeight;
    RenderStyle* style = [self.delegate.styles forLine:line];
    if (style.lineHeight > 0) lineHeight = style.lineHeight;
    
	NSString *str = [line stripFormattingWithSettings:self.delegate.settings];
	NSString *retain = @"";

    BeatPaperSize paperSize = self.delegate.settings.paperSize;
    
    // Get block size
    CGFloat width = [style widthWithPageSize:paperSize];
    if (width == 0.0) width = [self.delegate.styles.page defaultWidthWithPageSize:paperSize];
    
    // This is a hack for some weird situations
    remainingSpace -= 1.0;

    bool breakParagraph = (mode == BeatParagraphPaginationModeDefault && line.type == action);
    
    // For some pagination modes, we might need to stop here
    if (mode != BeatParagraphPaginationModeDefault && line.type == action) {
        // This has to be broken, because it's too big to fit even on the next page
        if (self.height > self.delegate.maxPageHeight - 1.0) {
            breakParagraph = true;
        }
    }

    if (breakParagraph) {
        // Default mode paginates paragraphs pretty indiscriminately
        NSInteger length = [self getOverflowLength:line lineHeight:lineHeight remainingSpace:remainingSpace string:str];
        
        // If there's something to retain, let's split the string.
        if (length > 0) {
            // In some cases length can be longer than the actual string, which... I don't know.
            // I think this can happen in non-monospaced fonts, but not sure. Let's avoid this.
            if (length > str.length) length -= length - str.length;
            retain = [str substringToIndex:length];
        }
        
        NSArray *splitElements = [line splitAndFormatToFountainAt:retain.length];
        Line *prePageBreak = splitElements[0];
        Line *postPageBreak = splitElements[1];
        
        NSArray* onNextPage = (postPageBreak.length > 0) ? @[postPageBreak] : @[];
        
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:retain.length element:line attributedString:[line attributedStringForOutputWith:_delegate.settings] reason:@"Paragraph split"];
        return @[@[prePageBreak], onNextPage, pageBreak];
    } else {
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:line attributedString:[line attributedStringForOutputWith:_delegate.settings] reason:@"Avoid paragraph split"];
        return @[@[], @[line], pageBreak];
    }
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
    BeatPageBreak* pageBreak;
	
	if (leftBlock.height > remainingSpace) {
		// We need to split left side
		leftResult = [leftBlock breakBlockWithRemainingSpace:remainingSpace];
		[onThisPage addObjectsFromArray:leftResult[0]];
		[onNextPage addObjectsFromArray:leftResult[1]];
    } else {
        [onThisPage addObjectsFromArray:leftBlock.lines];
    }
	if (rightBlock.height > remainingSpace) {
		// We need to split left side
		rightResult = [rightBlock breakBlockWithRemainingSpace:remainingSpace];
		[onThisPage addObjectsFromArray:rightResult[0]];
		[onNextPage addObjectsFromArray:rightResult[1]];
    } else {
        [onThisPage addObjectsFromArray:rightBlock.lines];
    }
	    
    // If something was left on both pages, let's return that result.
    if (onThisPage.count > 0 && onNextPage.count > 0) {
        BeatPageBreak* leftPB = (leftResult.count == 3) ? leftResult[2] : nil;
        BeatPageBreak* rightPB = (rightResult.count == 3) ? rightResult[2] : nil;
        
        // A fallback page break
        if (leftPB == nil) leftPB = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"Weird dual dialogue issue?"];
        
        return @[onThisPage, onNextPage, (rightPB != nil) ? rightPB : leftPB];
    }
    
    // To be on the safe side, we'll also try this.
    else if (((NSArray*)leftResult[0]).count > 0 && ((NSArray*)rightResult[0]).count > 0) {
		return @[onThisPage, onNextPage, rightResult[2]];
    }
	
    pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"Nothing was left on page with dual dialogue container"];
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
    NSIndexSet* splittableIndices = [self possiblePageBreakIndicesForDialogueBlock];
    // List of safe lines which can be left on current page
    NSMutableArray<Line*>* safeLines = NSMutableArray.new;
    
    CGFloat maxHeight = _delegate.maxPageHeight - _delegate.styles.page.lineHeight * 2;
    bool splitCharacterCue = false;
    
    // Iterate through elements in dialogue block and see where we no longer can fit anything on page
    for (NSInteger i=1; i<dialogueBlock.count; i++) {
        Line* line = dialogueBlock[i];
                
        CGFloat heightBefore = [self heightUntil:line];
        CGFloat h = heightBefore + [self heightForLine:line];
        
        if (h <= remainingSpace) {
            // This line fits, handle it
            if ((line.isAnyDialogue && i > 0) || line == dialogueBlock.lastObject) {
                // We got to the end of block safely
                [onThisPage addObjectsFromArray:safeLines];
                [onThisPage addObject:line];
                // Flush safe lines
                [safeLines removeAllObjects];
            } else {
                [safeLines addObject:line];
            }
            
            continue;
        }
        
        // In some edge cases you could end up with a parenthetical or character cue that is longer than a page, which will cause an endless loop, because it will now fit anywhere. To avoid that, we'll check the item height and force-split it if needed.
        if (i <= 1 && heightBefore > maxHeight) {
            splitCharacterCue = true;
            
            // We have encountered a character cue which is higher than a page. Rare edge case.
            line = dialogueBlock.firstObject;
            NSArray* splitCue = [self splitParagraphWithRemainingSpace:remainingSpace line:line];
            Line* retain = ((NSArray*)splitCue[0]).firstObject;
            Line* split = ((NSArray*)splitCue[1]).firstObject;
            
            if (retain.length > 0) {
                cutoff = 1;
                [tmpThisPage addObject:retain];
                pageBreak = splitCue[2];
            }
            
            if (split.length > 0) [tmpNextPage addObject:split];
            break;
            
        } else if (line.isAnyParenthetical && [self heightForLine:line] > maxHeight) {
            NSArray* splitParenthetical = [self splitParagraphWithRemainingSpace:remainingSpace - heightBefore line:line];
            Line* retain = ((NSArray*)splitParenthetical[0]).firstObject;
            Line* split = ((NSArray*)splitParenthetical[1]).firstObject;
            
            // Something was left on this page
            if (retain.length > 0) {
                [tmpThisPage addObjectsFromArray:safeLines];
                [tmpThisPage addObject:retain];
                cutoff += 1;
                
                pageBreak = splitParenthetical[2];
            }
            // Something was cut off to next page
            if (split.length > 0) [tmpNextPage addObject:split];
            
            break;
        }
        
        // This line doesn't fit. Let's find out how to split the block.
        
        if (line.type == dualDialogueCharacter) {
            // So, breaking with some Fountain standards, we support multiple dual dialogue items on the right side.
            cutoff = i;
            pageBreakItem = line;
            break;
        } else if (line.isAnyParenthetical) {
            // Parentheticals are a good place to split a line
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
        } else if (line.isAnyDialogue && !line.string.containsOnlyWhitespace) {
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
            
            if (split.length > 0 && retain.length > 0) {
                // Something was cut off to next page
                [tmpNextPage addObject:split];
            } else if (retain.length == 0 && split.length > 0 && [splittableIndices containsIndex:i]) {
                // Nothing was left on current page, we'll need to see if we actually can split the dialogue block here
                cutoff = i;
                
                // Set the correct page break item
                pageBreakItem = split;
                
                // Add remaining safe lines
                [tmpNextPage insertObjects:safeLines atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, safeLines.count)]];
            }
            break;
        } else if (line.isAnyDialogue && line.string.containsOnlyWhitespace) {
            // Handle whitespace-only lines
            cutoff = i + 1;
        }
    }
    
    // We'll cut off at 0, so make page break item the first object in array
    if (cutoff == 0) pageBreakItem = self.lines.firstObject;
    
    [onThisPage addObjectsFromArray:tmpThisPage];
    [onNextPage addObjectsFromArray:tmpNextPage];
    [onNextPage addObjectsFromArray:[self.lines subarrayWithRange:NSMakeRange(cutoff, self.lines.count - cutoff)]];
    
    // Add character cues if needed (usually is)
    if (!splitCharacterCue) {
        if (onThisPage.count && onNextPage.count && !onNextPage.firstObject.isAnyCharacter) {
            [onThisPage insertObject:self.lines.firstObject atIndex:0];
            [onThisPage addObject:[self.delegate moreLineFor:self.lines.firstObject]];
            
            Line* cue = [self.delegate contdLineFor:self.lines.firstObject];
            [onNextPage insertObject:cue atIndex:0];
        } else if (onThisPage.count) {
            [onThisPage insertObject:self.lines.firstObject atIndex:0];
        } else {
            [onNextPage insertObject:self.lines.firstObject atIndex:0];
        }
    }
    
    if (pageBreak == nil) {
        // Get page break index. If it's below 2 (or not found), make the first item be the page break.
        NSInteger pageBreakIndex = [self.lines indexOfObject:pageBreakItem];
        if ((pageBreakIndex == NSNotFound || pageBreakIndex <= 1) && onThisPage.count == 0) pageBreakItem = self.lines.firstObject;
    
        pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:pageBreakItem attributedString:nil reason:@"Dialogue cut"];
    }
    
    return @[ onThisPage, onNextPage, pageBreak ];
}


/// Splits a line of dialogue, retaining as much as possible in given remaining space.
- (NSArray*)splitDialogueLine:(Line*)line remainingSpace:(CGFloat)remainingSpace {
	// Regex for splitting into sentences
    NSRegularExpression* regex = [NSRegularExpression.alloc initWithPattern:@"(.+?[\\.\\?\\!…]+\\s*)" options:0 error:nil];
    
    // Create temporary string and catch sentences
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
    
    // We might not catch the last sentence, so make sure we're not missing anything, and if we are, bring it with us.
	if (length < string.length) {
		NSString *str = [string substringWithRange:NSMakeRange(length, string.length - length)];
		[sentences addObject:str];
	}

    // A fallback if we are paginating something that isn't really split into sentences.
    // Let's split it in words in that case.
    NSInteger firstSentenceHeight = [self heightForString:sentences.firstObject lineType:line.type];
    if ((CGFloat)firstSentenceHeight > self.delegate.maxPageHeight - self.delegate.styles.page.lineHeight * 2) {
        sentences = [string componentsSeparatedByString:@" "].mutableCopy;
        
        // This is something that is NOT separated by spaces, probably a very long word. Let's split it by each character. This is VERY silly, but fixes possible crashes with single words that are over a page long. Edge case if there ever was one.
        if (sentences.count == 1) {
            NSString* sentence = sentences.firstObject;
            NSMutableArray<NSString*>* characters = NSMutableArray.new;
            for (NSInteger i=0; i<sentence.length; i++) {
                [characters addObject:[sentence substringWithRange:NSMakeRange(i, 1)]];
            }
            
            sentences = characters;
        }
    }
        
	NSMutableString* text = NSMutableString.new;
	NSInteger breakLength = 0;
	CGFloat breakPosition = 0.0;
    
    // Next, let's find out how much we can fit on this page
	for (NSString *sentence in sentences) { @autoreleasepool {
		[text appendString:sentence];
		CGFloat h = [self heightForString:text lineType:line.type];
        
        if (h < remainingSpace) { // Element fits
            breakLength += sentence.length;
            breakPosition += h;
		} else { // Element doesn't fit anymore
			break;
		}
	} }
        
	NSArray *p = [line splitAndFormatToFountainAt:breakLength];
    BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:breakLength element:line attributedString:[line attributedStringForOutputWith:_delegate.settings] reason:@"Break paragraph"];
    
	return @[p[0], p[1], pageBreak];
}


/// Returns the height of string for given line type.
/// - note: This method doesn't take margins or any other styles into account, just the width.
- (NSInteger)heightForString:(NSString *)string lineType:(LineType)type
{
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
/// @warning: This code uses **TextKit 1**
- (NSLayoutManager*)layoutManagerForString:(NSString*)string line:(Line*)line textStorage:(out NSTextStorage**)textStorage
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
    CGFloat width = [self.delegate.renderer blockWidthFor:line dualDialogue:false];
    if (width == 0.0) width = [self.delegate.styles.page defaultWidthWithPageSize:paperSize];
        
    NSAttributedString* attrStr = [self.delegate.renderer renderLine:line ofBlock:self dualDialogueElement:false firstElementOnPage:false];
            
    // set up the layout manager
    *textStorage   = [[NSTextStorage alloc] initWithAttributedString:attrStr];
    NSLayoutManager *layoutManager = NSLayoutManager.new;
    
    NSTextContainer *textContainer = NSTextContainer.new;
    [textContainer setSize:CGSizeMake(width, MAXFLOAT)];
    
    [layoutManager addTextContainer:textContainer];
    [*textStorage addLayoutManager:layoutManager];
    [textContainer setLineFragmentPadding:0];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    return layoutManager;
}


#pragma mark - Rendering blocks to attributed strings

- (NSAttributedString*)attributedString
{
	return [self attributedStringForFirstElement:false];
}
- (NSAttributedString*)attributedStringForFirstElementOnPage
{
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
