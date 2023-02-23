//
//  BeatPaginationBlock.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationBlock.h"
#import "BeatPagination.h"
#import <BeatParsing/BeatParsing.h>
#import "Beat-Swift.h"
#import "BeatPageBreak.h"

@interface BeatPaginationBlock ()
@property (nonatomic) CGFloat calculatedHeight;
@property (nonatomic) id<BeatPageDelegate> delegate;
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
			Line *firstLine = _lines.firstObject;
			if (firstLine.nextElementIsDualDialogue) {
				_dualDialogueContainer = true;
			}
		}
	}
	return self;
}

- (LineType)type {
	return self.lines.firstObject.type;
}

- (CGFloat)height {
	if (_calculatedHeight > 0.0) return _calculatedHeight;
	
	CGFloat height = 0.0;
	if (self.dualDialogueContainer) {
		CGFloat leftHeight = self.leftColumnBlock.height;
		CGFloat rightHeight = self.rightColumnBlock.height;
		
		if (leftHeight >= rightHeight) height = leftHeight;
		else height = rightHeight;
	} else {
		for (Line* line in self.lines) {
			if (line.isInvisible) continue;
			CGFloat lineHeight = [self heightForLine:line];
			height += lineHeight;
		}
	}
	
	_calculatedHeight = height;
	return height;
}

- (CGFloat)heightForLine:(Line*)line {
	// We'll cache the line heights in a dictionary by UUID
	if (self.lineHeights == nil) self.lineHeights = NSMutableDictionary.new;

	// If the height has already been calculated, return the result
	if (self.lineHeights[line.uuid] != nil) {
		return self.lineHeights[line.uuid].floatValue;
	}
	
	// Calculate the line height
	CGFloat height = 0.0;
	
	// Create a bare-bones paragraph style
	NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
	pStyle.maximumLineHeight = BeatPagination.lineHeight;
	
	NSAttributedString* string = [NSMutableAttributedString.alloc initWithString:line.stripFormatting attributes:@{
		NSFontAttributeName: _delegate.fonts.courier,
		NSParagraphStyleAttributeName: pStyle
	}];
	
	// If this is a *dual dialogue column*, we'll need to convert the style.
	LineType type = line.type;
	if (self.dualDialogueElement) {
		if (type == dialogue) type = dualDialogue;
		else if (type == character) type = dualDialogueCharacter;
		else if (type == dualDialogueParenthetical) type = dualDialogueParenthetical;
	}
	
	RenderStyle *style = [self.delegate.styles forElement:[Line typeName:type]];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	height = [string heightWithContainerWidth:width] + style.marginTop;
	
	// Save the calculated top margin if this is the first element on page
	if (line == self.lines.firstObject) self.topMargin = style.marginTop;
	
	self.lineHeights[line.uuid] = [NSNumber numberWithFloat:height];
	return height;
}

- (Line*)lineAt:(CGFloat)y {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		height += [self heightForLine:line];
		if (height >= y) return line;
	}
	
	return nil;
}

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

- (NSArray*)leftSideDialogue {
	NSMutableArray *lines = NSMutableArray.new;
	for (Line* line in self.lines) {
		if (line.type == dualDialogueCharacter) break;
		[lines addObject:line];
	}
	return lines;
}
- (NSArray*)rightSideDialogue {
	NSMutableArray *lines = NSMutableArray.new;
	for (Line* line in self.lines) {
		if (line.isDialogue) continue;
		[lines addObject:line];
	}
	return lines;
}

- (BeatPaginationBlock*)leftColumnBlock {
	if (_leftColumnBlock == nil) {
		_leftColumnBlock = [BeatPaginationBlock.alloc initWithLines:[self leftSideDialogue] delegate:self.delegate isDualDialogueElement:true];
	}
	return _leftColumnBlock;
}

- (BeatPaginationBlock*)rightColumnBlock {
	if (_rightColumnBlock == nil) {
		_rightColumnBlock = [BeatPaginationBlock.alloc initWithLines:[self rightSideDialogue] delegate:self.delegate isDualDialogueElement:true];
	}
	return _rightColumnBlock;
}


#pragma mark - Breaking block across pages

- (NSIndexSet*)possiblePageBreakIndices {
	// For every non-dialogue block, we'll just return 0
	Line* firstLine = self.lines.firstObject;
	if (!firstLine.isAnyCharacter) {
		return [NSIndexSet indexSetWithIndex:0];
	}

	NSMutableIndexSet* indices = [NSMutableIndexSet indexSetWithIndex:0];
	for (NSInteger i=0; i<self.lines.count; i++) {
		Line *line = _lines[i];
		
		if (line.isAnyDialogue || (line.isAnyParenthetical && i > 1))  {
			[indices addIndex:i];
		}
	}
	
	return indices;
}

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
		return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"No page break index found"]];
	}
	
	Line* spiller = [self findSpillerAt:remainingSpace];
	
	if (spiller.type == action) {
		// Break paragraphs into two if possible
		return [self splitParagraphWithRemainingSpace:remainingSpace];
	}
	else if (spiller.isDialogueElement || spiller.isDualDialogueElement) {
		return [self splitDialogueAt:spiller remainingSpace:remainingSpace];
	}
	else {
		return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"No page break index found"]];
	}
}

- (NSArray*)splitParagraphWithRemainingSpace:(CGFloat)remainingSpace {
	Line *line = self.lines.firstObject;
	NSString *str = line.stripFormatting;
	NSString *retain = @"";

	RenderStyle *style = [self.delegate.styles forElement:line.typeName];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	
	// Create the layout manager for remaining space calculation
	NSLayoutManager *lm = [self heightCalculatorForString:str width:width];
	
	// We'll get the number of lines rather than calculating exact size in NSTextField
	__block NSInteger numberOfLines = 0;
	
	// Iterate through line fragments
	__block CGFloat pageBreakPos = 0;
	__block NSInteger length = 0;
	
	[lm enumerateLineFragmentsForGlyphRange:NSMakeRange(0, lm.numberOfGlyphs) usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		numberOfLines++;
		if (numberOfLines < remainingSpace / BeatPagination.lineHeight) {
			NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
			length += charRange.length;
			//pageBreakPos += usedRect.size.height;
			pageBreakPos += numberOfLines * BeatPagination.lineHeight;
		} else {
			*stop = true;
		}
	}];
		
	retain = [str substringToIndex:length];
	
	NSArray *splitElements = [line splitAndFormatToFountainAt:retain.length];
	Line *prePageBreak = splitElements[0];
	Line *postPageBreak = splitElements[1];
	
	BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:pageBreakPos element:line reason:@"Paragraph split"];
	return @[@[prePageBreak], @[postPageBreak], pageBreak];
}

- (NSArray*)splitDualDialogueWithRemainingSpace:(CGFloat)remainingSpace {
	NSArray *left = [self leftSideDialogue];
	NSArray *right = [self rightSideDialogue];
	
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
	
	BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"Nothing was left on page with dual dialogue container"];
	return @[@[], self.lines, pageBreak];
}

- (NSArray*)splitDialogueAt:(Line*)spiller remainingSpace:(CGFloat)remainingSpace {
	remainingSpace -= BeatPagination.lineHeight; // Make space for (MORE) etc.
	
	NSMutableArray *dialogueBlock = self.lines.mutableCopy;

	BeatPageBreak *pageBreak;
	Line *pageBreakItem;
	NSUInteger index = [dialogueBlock indexOfObject:spiller];
	
	if (spiller) {
		// If there is a spiller, calculate the height of the remaining block
		remainingSpace -= [self heightUntil:spiller];
	}
	
	// If nothing fits, move the whole block on next page
	if (remainingSpace < BeatPagination.lineHeight) {
		return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"No page break index found"]];
	}
	
	// Arrays for elements
	NSMutableArray *onThisPage = NSMutableArray.new;
	NSMutableArray *onNextPage = NSMutableArray.new;
	// Arrays for faux elements which are created while paginating
	NSMutableArray *tmpThisPage = NSMutableArray.new;
	NSMutableArray *tmpNextPage = NSMutableArray.new;
	
	// Indices in which we could split the block.
	// When we can't split the block at current item, we'll fall back to the previous possible index.
	NSIndexSet* splittableIndices = [self possiblePageBreakIndices];
	
	// Split the block at this location
	NSUInteger splitAt = (index > 0) ? [splittableIndices indexLessThanOrEqualToIndex:index] : 0;
	
	// Live pagination page break item
	pageBreakItem = dialogueBlock[splitAt];

	// For dialogue, we'll see if we can split the current line of dialogue
	if (spiller.isAnyDialogue) {
		if (remainingSpace > BeatPagination.lineHeight) {
			// Split dialogue according to remaining space
			NSArray* splitLine = [self splitDialogueLine:spiller remainingSpace:remainingSpace];
			
			Line* retain = splitLine[0];
			
			if (retain.length > 0) {
				[tmpThisPage addObject:splitLine[0]];
				[tmpNextPage addObject:splitLine[1]];
				pageBreak = splitLine[2];
				
				[dialogueBlock removeObject:spiller];
			} else {
				// Nothing fit
				splitAt = [splittableIndices indexLessThanIndex:splitAt];
				pageBreakItem = dialogueBlock[splitAt];
			}
		}
		else {
			// This line of dialogue does not fit on page
			splitAt = [splittableIndices indexLessThanIndex:splitAt];
			pageBreakItem = dialogueBlock[splitAt];
		}
	}
		
	// Don't allow only a single element to stay on page
	if (splitAt == 1 && tmpThisPage.count == 0) splitAt = 0;
	
	// If something is left behind on the current page, split it
	if (splitAt > 0) {
		// Don't allow the last element in block to be parenthetical
		Line *prevElement = dialogueBlock[splitAt - 1];
		if (prevElement.isAnyParenthetical && tmpThisPage.count == 0) splitAt -= 1;
		
		// Split the block
		[onThisPage addObjectsFromArray:
			 [dialogueBlock subarrayWithRange:NSMakeRange(0, splitAt)]
		];
		[onThisPage addObjectsFromArray:tmpThisPage];
		
		if (self.delegate) [onThisPage addObject:[self.delegate moreLineFor:spiller]];
	}
			
	// Add stuff on next page if needed
	if (onThisPage.count) [onNextPage addObject:[self.delegate contdLineFor:dialogueBlock.firstObject]];
	[onNextPage addObjectsFromArray:tmpNextPage];
	NSRange splitRange = NSMakeRange(splitAt, dialogueBlock.count - splitAt);
	if (splitRange.length > 0) [onNextPage addObjectsFromArray:[dialogueBlock subarrayWithRange:splitRange]];
	
	// Sorry, this is a mess. pageBreak could be defined earlier on, because it's provided by splitDialogueLine.
	if (pageBreak == nil) pageBreak = [BeatPageBreak.alloc initWithY:0 element:pageBreakItem reason:@"Dialogue break"];
	return @[ onThisPage, onNextPage, pageBreak ];
}

- (NSArray*)splitDialogueLine:(Line*)line remainingSpace:(CGFloat)remainingSpace {
	NSRegularExpression* regex = [NSRegularExpression.alloc initWithPattern:@"(.+?[\\.\\?\\!…]+\\s*)" options:0 error:nil];
	NSString* string = line.stripFormatting;
	NSArray* matches = [regex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
	
	NSMutableArray<NSString*>* sentences = NSMutableArray.new;
	NSInteger length = 0;
	
	// Gather matches
	for (NSTextCheckingResult *match in matches) {
		NSString *str = [string substringWithRange:match.range];
		length += str.length;
		
		[sentences addObject:str];
	}
	
	// Make sure we're not missing anything
	if (length < string.length) {
		NSString *str = [string substringWithRange:NSMakeRange(length, string.length - length)];
		[sentences addObject:str];
	}
	
	NSMutableString* text = NSMutableString.new;
	NSInteger breakLength = 0;
	CGFloat breakPosition = 0.0;
	
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
	BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:breakPosition element:line reason:@"Break paragraph"];
	return @[p[0], p[1], pageBreak];
}

- (NSInteger)heightForString:(NSString *)string lineType:(LineType)type
{
	// This method MIGHT NOT work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	// BTW, why won't I conver this method to use NSLayoutManager?
	
	CGFloat lineHeight = BeatPagination.lineHeight;
	if (string.length == 0) return lineHeight;
	
	// If this is a *dual dialogue* column, we'll need to convert the style.
	if (self.dualDialogueElement && (type == dialogue || type == character || type == parenthetical)) {
		if (type == dialogue) type = dualDialogue;
		else if (type == character) type = dualDialogueCharacter;
		else if (type == dualDialogueParenthetical) type = dualDialogueParenthetical;
	}
	
	BeatFont* font = self.delegate.fonts.courier;
	RenderStyle *style = [self.delegate.styles forElement:[Line typeName:type]];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
	font = [font fontWithSize:font.pointSize * 0.8];
#endif
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
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

- (NSLayoutManager*)heightCalculatorForString:(NSString*)string width:(CGFloat)width {
	BeatFont *font = _delegate.fonts.courier;
	if (string == nil) string = @"";
	
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
	font = [font fontWithSize:font.pointSize * 0.8];
#endif
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = NSLayoutManager.new;

	NSTextContainer *textContainer = NSTextContainer.new;
	[textContainer setSize:CGSizeMake(width, MAXFLOAT)];

	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0];
	[layoutManager glyphRangeForTextContainer:textContainer];
	
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

- (CGFloat)widthFor:(Line*)line {
	RenderStyle* style = [_delegate.styles forElement:line.typeName];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	return width;
}

#pragma mark - Convenience

/// Returns an array of line UUIDs
- (NSArray<NSUUID*>*)UUIDs {
	if (_UUIDs == nil) {
		NSMutableArray* UUIDs = NSMutableArray.new;
		for (Line* line in self.lines) {
			[UUIDs addObject:line.uuid];
		}
		_UUIDs = UUIDs;
	}
	
	return _UUIDs;
}

- (bool)containsLine:(Line*)line {
	return [self.UUIDs containsObject:line.uuid];
}

@end
