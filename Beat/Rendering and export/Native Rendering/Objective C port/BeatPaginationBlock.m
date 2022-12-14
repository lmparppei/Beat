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

@interface BeatPaginationBlock ()
@property (nonatomic) bool dualDialogueElement;
@property (nonatomic) bool dualDialogueContainer;
@property (nonatomic) NSAttributedString* renderedString;
@property (nonatomic) CGFloat calculatedHeight;

// Dual dialogue blocks
@property (nonatomic) NSMutableAttributedString* leftColumn;
@property (nonatomic) NSMutableAttributedString* rightColumn;

@property (nonatomic) BeatPaginationBlock* leftColumnBlock;
@property (nonatomic) BeatPaginationBlock* rightColumnBlock;

@property (nonatomic) id<BeatPageDelegate> delegate;

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
	if (_calculatedHeight > 0) return _calculatedHeight;
	
	CGFloat height = 0.0;
	if (self.dualDialogueContainer) {
		CGFloat leftHeight = self.leftColumnBlock.height;
		CGFloat rightHeight = self.rightColumnBlock.height;
		
		if (leftHeight >= rightHeight) height = leftHeight;
		else height = rightHeight;
	} else {
		for (Line* line in self.lines) {
			height += [self heightForLine:line];
		}
	}
	
	return height;
}

- (CGFloat)heightForLine:(Line*)line {
	if (self.lineHeights == nil) self.lineHeights = NSMutableDictionary.new;
	if (self.lineHeights[line.uuid] != nil) return self.lineHeights[line.uuid].floatValue;
	
	CGFloat height = 0.0;
	
	NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
	pStyle.maximumLineHeight = BeatPagination.lineHeight;
	
	NSAttributedString* string = [NSMutableAttributedString.alloc initWithString:line.stripFormatting attributes:@{
		NSFontAttributeName: _delegate.fonts.courier,
		NSParagraphStyleAttributeName: pStyle
	}];
	
	RenderStyle *style = [self.delegate.styles forElement:line.typeName];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	
	height = [string heightWithContainerWidth:width] + style.marginTop;
	
	self.lineHeights[line.uuid] = [NSNumber numberWithFloat:height];
	return height;
}

- (NSAttributedString*)attributedString {
	if (_renderedString == nil) {
		if (self.dualDialogueContainer) {
			//
			NSLog(@"## DUAL DIALOGUE RENDERING MISSING");
		}
		
		NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
		for (Line* line in self.lines) { @autoreleasepool {
			NSAttributedString *lineStr = [self renderLine:line];
			[attrStr appendAttributedString:lineStr];
			
			_renderedString = attrStr;
		} }
	}
	
	return _renderedString;
}

/// Create and render the individual line elements
- (NSAttributedString*)renderLine:(Line*)line {
	return [self renderLine:line firstElementOnPage:false];
}

- (NSAttributedString*)renderLine:(Line*)line firstElementOnPage:(bool)firstElementOnPage {
	self.leftColumn = nil;
	self.rightColumn = nil;
	
	NSMutableAttributedString *attributedString = NSMutableAttributedString.new;
	
	return attributedString;
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
-(NSArray*)splitBlockWithRemainingSpace:(CGFloat)remainingSpace {
	// Dual dialogue requires different logic
	if (self.dualDialogueContainer) {
		return [self splitDualDialogueWithRemainingSpace:remainingSpace];
	}
	
	NSMutableArray<Line*>* onThisPage = NSMutableArray.new;
	NSMutableArray<Line*>* onNextPage = NSMutableArray.new;
	
	NSMutableArray<Line*>* tmpThisPage = NSMutableArray.new;
	NSMutableArray<Line*>* tmpNextPage = NSMutableArray.new;
	
	BeatPageBreak *pageBreak;
	
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
	NSLog(@"#### IMPLEMENT PARAGRAPH SPLITTING");
	return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"Paragraph"]];
}

- (NSArray*)splitDualDialogueWithRemainingSpace:(CGFloat)remainingSpace {
	NSLog(@"#### IMPLEMENT DUAL DIALOGUE CONTAINER SPLITTING");
	return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"Dual dialogue container"]];
}

- (NSArray*)splitDialogueAt:(Line*)spiller remainingSpace:(CGFloat)remainingSpace {
	remainingSpace -= BeatPagination.lineHeight; // Make space for (MORE) etc.
	
	NSMutableArray *dialogueBlock = self.lines.mutableCopy;

	Line *pageBreakItem;
	CGFloat suggestedPageBreak = 0;
	NSUInteger index = [dialogueBlock indexOfObject:spiller];
	
	if (spiller) {
		// If there is a spiller, calculate the height of the remaining block
		NSArray *blockUntilSpiller = [dialogueBlock subarrayWithRange:NSMakeRange(0, index)];
		remainingSpace -= [self heightUntil:spiller];
	}
	
	// If nothing fits, move the whole block on next page
	if (remainingSpace < BeatPaginator.lineHeight) {
		return @[@[], self.lines, [BeatPageBreak.alloc initWithY:0 element:self.lines.firstObject reason:@"No page break index found"]];
	}
	
	BeatPageBreak *pageBreak;
	
	// Arrays for elements
	NSMutableArray *onThisPage = NSMutableArray.new;
	NSMutableArray *onNextPage = NSMutableArray.new;
	// Arrays for faux elements which are created while paginating
	NSMutableArray *tmpThisPage = NSMutableArray.new;
	NSMutableArray *tmpNextPage = NSMutableArray.new;
	
	// Indices in which we could split the block.
	// When we can't split the block at current item, we'll fall back to the previous possible index.
	NSIndexSet *splittableIndices = [self possiblePageBreakIndices];
	
	// Split the block at this location
	NSUInteger splitAt = (index > 0) ? [splittableIndices indexLessThanOrEqualToIndex:index] : 0;
	
	// Live pagination page break item
	pageBreakItem = dialogueBlock[splitAt];

	// For dialogue, we'll see if we can split the current line of dialogue
	if (spiller.isAnyDialogue) {
		if (remainingSpace > BeatPaginator.lineHeight) {
			// Split dialogue according to remaining space
			NSArray * splitLine = [self splitDialogueLine:spiller remainingSpace:remainingSpace];
			
			Line * retain = splitLine[0];
			
			if (retain.length > 0) {
				[tmpThisPage addObject:splitLine[0]];
				[tmpNextPage addObject:splitLine[1]];
				pageBreak = splitLine[2];
				
				[dialogueBlock removeObject:spiller];
			} else {
				// Nothing fit
				lkjök
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
		[onThisPage addObject:[BeatPaginator moreLineFor:spiller]];
	}
			
	// Add stuff on next page if needed
	if (onThisPage.count) [onNextPage addObject:[BeatPaginator contdLineFor:dialogueBlock.firstObject]];
	[onNextPage addObjectsFromArray:tmpNextPage];
	NSRange splitRange = NSMakeRange(splitAt, dialogueBlock.count - splitAt);
	if (splitRange.length > 0) [onNextPage addObjectsFromArray:[dialogueBlock subarrayWithRange:splitRange]];
	
	
	BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:suggestedPageBreak element:pageBreakItem reason:@"Dialogue break"];
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
		NSString *str = [str substringWithRange:NSMakeRange(length, string.length - length)];
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

/*
 // MARK: Break a line of dialogue

	 
	 let p = element.line.splitAndFormatToFountain(at: breakLength)!
	 return (p[0], p[1], breakPosition)
 }
 */

- (NSInteger)heightForString:(NSString *)string lineType:(LineType)type
{
	/*
	 This method MIGHT NOT work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	CGFloat lineHeight = BeatPagination.lineHeight;
	if (string.length == 0) return lineHeight;
	
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

@end
