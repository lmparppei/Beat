//
//  FNPaginator.m
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Parts © 2019 Lauri-Matti Parppei / KAPITAN!
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

/*
 
 N.B. This file is heavily modified for Beat, compared to the original.
 
 It is duct-taped together to give somewhat acceptable pagination results when using European page sizes, and now also splits paragraphs into parts. There are quite a few bugs, I guess, but for now it kind of works together with my custom CSS.
 
 This comment has been pretty unhelpful for anyone stumbling upon this file some day. Try to make something out of it. I might be gone but the code lives on.
 
 "Remember the flight
 the bird is mortal"
 (Forough Farrokhzad)
 
 */

#import "FNPaginator.h"
#import "FNScript.h"
#import "FNElement.h"
//#import "RegexKitLite.h"
#import "RegExCategories.h"

@interface FNPaginator ()

@property (strong, nonatomic) NSDocument *document;
@property (strong, nonatomic) FNScript *script;
@property (strong, nonatomic) NSMutableArray *pages;

@end

@implementation FNPaginator

- (id)initWithScript:(FNScript *)aScript
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = aScript;
	}
	return self;
}
- (id)initWithScript:(FNScript *)aScript document:(NSDocument*)aDocument
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = aScript;
		_document = aDocument;
	}
	return self;
}

// Default pagination function for US Letter paper size
- (void)paginate
{
	if (self.document) {
		// Get paper size from the document
		CGSize paperSize = CGSizeMake(self.document.printInfo.paperSize.width, self.document.printInfo.paperSize.height);
		
		// run pagination
		[self paginateForSize:paperSize];
	} else {
		// US letter paper size is 8.5 x 11 (in pixels)
		CGSize letterPaperSize = CGSizeMake(612, 792);
		
		// run pagination
		[self paginateForSize:letterPaperSize];
	}
}

- (NSArray *)pageAtIndex:(NSUInteger)index
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if ([self.pages count] == 0) {
		[self paginate];
	}
	
	// Make sure we don't try and access an index that doesn't exist
	if ([self.pages count] == 0 || (index > [self.pages count] - 1)) {
		return @[];
	}
	
	return self.pages[index];
}

- (NSUInteger)numberOfPages
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if ([self.pages count] == 0) {
		[self paginate];
	}
	return [self.pages count];
}

- (void)paginateForSize:(CGSize)pageSize
{
	@autoreleasepool {
		bool debug = false;
		
		NSInteger oneInchBuffer = 72;
		NSInteger maxPageHeight =  pageSize.height - round(oneInchBuffer * 1.8);
		
		if (debug) NSLog(@"Papersize: %f - maxheight %lu", pageSize.height, oneInchBuffer);
		
		QUQFont *font = [QUQFont fontWithName:@"Courier" size:12];
		//NSInteger lineHeight = font.pointSize * 1.1;
		NSInteger lineHeight = font.pointSize;
		
		CGFloat spaceBefore;
		CGFloat elementWidth;
		CGFloat blockHeight = 0;
		
		NSInteger initialY = 0; // initial starting point on page
		NSInteger currentY = initialY;
		NSMutableArray *currentPage = [NSMutableArray array];
		
		// create a tmp array that will hold elements to be added to the pages
		NSMutableArray *tmpElements = [NSMutableArray array];
		NSInteger maxElements = [self.script.elements count];
		
		NSInteger previousDualDialogueBlockHeight = -1;
		
		// walk through the elements array
		for (NSInteger i = 0; i < maxElements; i++) {
			FNElement *element  = (self.script.elements)[i];
			
			// Skip invisible elements
			if ([element.elementType isEqualToString:@"Synopsis"] || [element.elementType isEqualToString:@"Section Heading"] ||
				[element.elementType isEqualToString:@"Boneyard"]) {
				continue;
			}
			
			// catch page breaks immediately
			if ([element.elementType isEqualToString:@"Page Break"]) {
				
				if ([tmpElements count] > 0) {
					for (FNElement *e in tmpElements) {
						[currentPage addObject:e];
					}
					
					// reset the tmp elements holder
					tmpElements = [NSMutableArray array];
				}
				
				// close the open page
				[currentPage addObject:element];
				[self.pages addObject:currentPage];
				
				if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
				
				// reset currentPage and the currentY value
				currentPage = [NSMutableArray array];
				currentY    = initialY;
				
				continue;
			}
			
			// get spaceBefore, the leftMargin, and the elementWidth
			spaceBefore         = [FNPaginator spaceBeforeForElement:element] * lineHeight;
			elementWidth        = [FNPaginator widthForElement:element];
			
			// get the height of the text
			NSInteger height    = [FNPaginator heightForString:element.elementText font:font maxWidth:elementWidth lineHeight:lineHeight];
			
			// data integrity check
			if (height <= 0) {
				// height = lineHeight;
				continue;
			}
			
			blockHeight += height;
			
			// only add the space before if we're not at the top of the current page
			if ([currentPage count] > 0) {
				blockHeight += spaceBefore;
			}
			
			// Fix to get styling to show up in PDFs. I have no idea.
			if (![element.elementText isMatch:RX(@" $")]) {
				element.elementText = [NSString stringWithFormat:@"%@%@", element.elementText, @""];
			}
			
			// Next part will handle checking if we want to break things on separate pages. It should work now. Original FNPaginator didn't break apart action paragraphs (I'm not sure if that's an American thing?) but we will do it. Also, this breaks apart dialogue blocks pretty nicely. Both SHOULD be agnostic to paper height.
			
			// if it's a screne heading, get the next block
			if ([element.elementType isEqualToString:@"Scene Heading"] && i+1 < maxElements) {
				FNElement *nextElement = (self.script.elements)[i+1];
				NSInteger nextElementWidth = [FNPaginator widthForElement:nextElement];
				NSInteger nextElementHeight = [FNPaginator heightForString:nextElement.elementText font:font maxWidth:nextElementWidth lineHeight:lineHeight];
				
				double overflow = maxPageHeight - (blockHeight + currentY + nextElementHeight);
				
				if (overflow < 0 && fabs(overflow) <= lineHeight * 3) {
					FNElement *forcedBreak = [[FNElement alloc] init];
					forcedBreak.elementType = @"Page Break";
					forcedBreak.elementText = @"";
					[tmpElements addObject:forcedBreak];
					[tmpElements addObject:element];
					continue;
				}
				
				[tmpElements addObject:element];
				//continue;
				
			}
			// if it's a character cue, we need to get the entire dialogue block
			else if ([element.elementType isEqualToString:@"Character"] && i+1 < maxElements) {
				NSSet *dialogueBlockTypes = [NSSet setWithObjects:@"Dialogue", @"Parenthetical", nil];
				
				NSInteger j             = i + 1;
				FNElement *nextElement  = element;
				BOOL isEndOfArray       = NO;
				do {
					[tmpElements addObject:nextElement];
					
					if (j < maxElements) {
						nextElement = (self.script.elements)[j++];
						if ([dialogueBlockTypes containsObject:nextElement.elementType]) {
							blockHeight += [FNPaginator heightForString:nextElement.elementText font:font maxWidth:elementWidth lineHeight:lineHeight];
						}
					}
					else {
						isEndOfArray = YES;
					}
					
				} while (!isEndOfArray && [dialogueBlockTypes containsObject:nextElement.elementType]);
				
				// reset i to j - 2 because we need to hit the last element again (j - 1) and the loop will
				// auto iterate +1 the next time through (so -2 total)
				if (isEndOfArray) {
					// if the script ends in a dialogue block, we need this to make sure we don't duplicate the last line.
					i = j - 1;
				}
				else {
					i = j - 2;
				}
				
				if (element.isDualDialogue && previousDualDialogueBlockHeight < 0) {
					previousDualDialogueBlockHeight = blockHeight;
				}
				else if (element.isDualDialogue) {
					NSInteger heightDiff = ABS(previousDualDialogueBlockHeight - blockHeight);
					blockHeight = heightDiff;
					previousDualDialogueBlockHeight = -1;
				}
			}
			else {
				[tmpElements addObject:element];
			}
			
			NSInteger totalHeightUsed = blockHeight + currentY;
			
			// Measure total height
			if (debug) NSLog(@"%ld/%f/%f (%lu/%lu) - %@", (long)height, blockHeight, spaceBefore, totalHeightUsed, maxPageHeight, element.elementText);
			
			// At the end of the page
			if (totalHeightUsed > maxPageHeight) {
				if (debug) {
					NSLog(@"exceeded page by %lu / limit %lu", totalHeightUsed - maxPageHeight, lineHeight * 2);
					NSLog(@"current y %lu / max height %lu", currentY, maxPageHeight);
				}
				
				// Split actions in two
				// ©KAPITAN!
				if ([tmpElements count] > 0 && [[tmpElements[0] elementType] isEqualToString:@"Action"] &&
					((totalHeightUsed - maxPageHeight) >= (lineHeight * 1)) &&
					(maxPageHeight - currentY) > lineHeight) {
					FNElement *action = tmpElements[0];
					
					// Max line width is 58 characters. Let's see how many lines are over the page.
					NSInteger pageOverflow = totalHeightUsed - maxPageHeight;
					
					// Count how many lines will overflow
					NSInteger linesOverflow = (blockHeight - pageOverflow) / lineHeight;
					if (linesOverflow == 0) linesOverflow = 1;
					
					if (linesOverflow > 1) {
						// Split into words
						NSInteger wordIndex     = -1;
						NSMutableArray *words 	= [NSMutableArray arrayWithArray:[action.elementText componentsSeparatedByString:@" "]];
						NSInteger actionHeight = 0;
					
						NSMutableString *retain = [NSMutableString stringWithString:@""];
						NSInteger retainHeight = height - pageOverflow;
					
						while ((actionHeight < retainHeight) && [words count]) {
							wordIndex++;
							NSString *text = [NSString stringWithFormat:@"%@ %@", retain, words[0]];
							NSInteger h = [FNPaginator heightForString:text font:font maxWidth:[FNPaginator widthForElement:action] lineHeight:lineHeight];
							actionHeight = h;
							
							if (actionHeight < retainHeight) {
								[retain appendString:words[0]];
								[retain appendString:@" "];
								[words removeObject:words[0]];
							}
						}
					
						// Put the first part onto current page
						FNElement * firstBlock = [[FNElement alloc] init];
						firstBlock.elementType = @"Action";
						firstBlock.elementText = retain;
						[currentPage addObject:firstBlock];
					
						// Update the old element to contain the latter part of the paragraph
						NSMutableString *cutoff = [NSMutableString string];
						for (NSInteger z = 0; z < [words count]; z++) {
							[cutoff appendString:words[z]];
							[cutoff appendString:@" "];
						}
						action.elementText = cutoff;
					}
				}
				
				// This is how we handle breaking a Character's dialogue across pages
				if ([tmpElements count] > 0 && [[tmpElements[0] elementType] isEqualToString:@"Character"] && ((totalHeightUsed - maxPageHeight) >= (lineHeight * 3))) {
					if (debug) printf("break character\n");
					NSInteger blockIndex        = -1;   // initial to -1 because we interate immediately
					NSInteger maxTmpElements    = [tmpElements count];
					
					// if there are two lines free below the character cue, we can try to squeeze this block in.
					NSInteger partialHeight = 0;
					NSInteger pageOverflow  = totalHeightUsed - maxPageHeight;
					
					// figure out what index spills over the page
					//while ((partialHeight < pageOverflow) && (blockIndex < maxTmpElements - 1)) {
					//NSLog(@" -> %lu / %lu", pageOverflow, partialHeight);
					while ((currentY + partialHeight < maxPageHeight) && (blockIndex < maxTmpElements - 1)) {
						blockIndex++;
						FNElement *e = tmpElements[blockIndex];
						NSInteger h  = [FNPaginator heightForString:e.elementText font:font maxWidth:[FNPaginator widthForElement:e] lineHeight:lineHeight];
						NSInteger s  = [FNPaginator spaceBeforeForElement:e] * round(lineHeight);
						partialHeight += h + s;
						if (debug) printf(" -> %lu", pageOverflow);
						if (debug) printf("/ %lu\n", partialHeight);
					}

					if (blockIndex > 0) {
						// determine what type of element spills
						FNElement *spiller = tmpElements[blockIndex];
						if (debug) printf("   spiller was %s\n", [spiller.elementType UTF8String]);
						
						if ([spiller.elementType isEqualToString:@"Parenthetical"]) {
							// break before, unless we're index 1 (the second element)
							if (blockIndex > 1) {
								for (NSInteger z = 0; z < blockIndex; z++) {
									[currentPage addObject:tmpElements[z]];
								}
								
								// add the more at the bottom of the page
								FNElement *more = [[FNElement alloc] init];
								more.elementType = @"Character";
								more.elementText = @"(MORE)";
								
								[currentPage addObject:more];
								
								// close the page
								[self.pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								
								if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
								
								// reset the block height
								blockHeight = 0;
								
								// add the remaining elements, plus the character cue, to the previous page
								FNElement *characterCue = tmpElements[0];
								characterCue.elementText = [NSString stringWithFormat:@"%@ (CONT'D)", characterCue.elementText];
								
								blockHeight += [FNPaginator heightForString:characterCue.elementText font:font maxWidth:[FNPaginator widthForElement:characterCue] lineHeight:lineHeight];
								
								[currentPage addObject:characterCue];
								
								for (NSInteger z = blockIndex; z < maxTmpElements; z++) {
									FNElement *e = tmpElements[z];
									[currentPage addObject:tmpElements[z]];
									blockHeight += [FNPaginator heightForString:e.elementText font:font maxWidth:[FNPaginator widthForElement:e] lineHeight:lineHeight];
								}
								
								// set the currentY
								currentY    = blockHeight;
								
								// reset the tmpElements
								tmpElements = [NSMutableArray array];
							}
							
						}
						else {
							//NSInteger distanceToBottom  = maxPageHeight - currentY - (lineHeight * 2);
							NSInteger distanceToBottom  = maxPageHeight - currentY - lineHeight;
							if (debug) NSLog(@"distance to bottom: %lu / %lu", distanceToBottom, currentY);
							
							if (distanceToBottom < lineHeight * 2) {
								[self.pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								currentY    = blockHeight - spaceBefore;
								blockHeight = 0;

								continue;
							}
							
							NSInteger heightBeforeDialogue = 0;
							for (NSInteger z = 0; z < blockIndex; z++) {
								FNElement *e = tmpElements[z];
								heightBeforeDialogue += [FNPaginator spaceBeforeForElement:e];
								heightBeforeDialogue += [FNPaginator heightForString:e.elementText font:font maxWidth:[FNPaginator widthForElement:e] lineHeight:lineHeight];
							}
							
							NSInteger dialogueHeight    = heightBeforeDialogue;
							
							/*
							NSInteger sentenceIndex     = -1;
							NSArray *sentences          = [spiller.elementText componentsMatchedByRegex:@"(.+?[\\.\\?\\!]+\\s*)" capture:1];
							NSInteger maxSentences      = [sentences count];
							
							NSMutableString *dialogueBeforeBreak = [NSMutableString string];
							
							while ((dialogueHeight < distanceToBottom) && (sentenceIndex < maxSentences - 1)) {
								sentenceIndex++;
								NSString *text = [NSString stringWithFormat:@"%@%@", dialogueBeforeBreak, sentences[sentenceIndex]];
								NSInteger h = [FNPaginator heightForString:text font:font maxWidth:[FNPaginator widthForElement:tmpElements[blockIndex]] lineHeight:lineHeight];
								dialogueHeight = h;
								
								if (dialogueHeight < distanceToBottom) {
									[dialogueBeforeBreak appendString:sentences[sentenceIndex]];
								}
							}
							 */
							
							NSInteger wordIndex     = -1;
							//NSArray *words          = [spiller.elementText componentsMatchedByRegex:@"( )" capture:1];
							NSArray *words 			= [spiller.elementText componentsSeparatedByString:@" "];
							NSInteger maxWords      = [words count];
							
							NSMutableString *dialogueBeforeBreak = [NSMutableString string];
							
							while ((dialogueHeight < distanceToBottom) && (wordIndex < maxWords - 1)) {
								wordIndex++;
								NSString *text = [NSString stringWithFormat:@"%@ %@", dialogueBeforeBreak, words[wordIndex]];
								NSInteger h = [FNPaginator heightForString:text font:font maxWidth:[FNPaginator widthForElement:tmpElements[blockIndex]] lineHeight:lineHeight];
								dialogueHeight = h;
								
								if (dialogueHeight < distanceToBottom) {
									[dialogueBeforeBreak appendString:words[wordIndex]];
									[dialogueBeforeBreak appendString:@" "];
								}
							}
							
							// now break up the sentences into two dialogue elements
							FNElement *preBreakDialogue = [[FNElement alloc] init];
							preBreakDialogue.elementType = @"Dialogue";
							preBreakDialogue.elementText = dialogueBeforeBreak;
							
							if (![preBreakDialogue.elementText isEqualToString:@""]) {
								// we need to split this element's text so that it fits on both pages
								for (NSInteger z = 0; z < blockIndex; z++) {
									[currentPage addObject:tmpElements[z]];
								}

								[currentPage addObject:preBreakDialogue];
								
								// add the more at the bottom of the page
								FNElement *more = [[FNElement alloc] init];
								more.elementType = @"More";
								more.elementText = @"(MORE)";
								
								[currentPage addObject:more];
								
								// close the page
								[self.pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
							}
							else {
								[self.pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								
								if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
								
								for (NSInteger z = 1; z < blockIndex; z++) {
									[currentPage addObject:tmpElements[z]];
								}
							}
							
							
							// reset the block height
							blockHeight = 0;
							
							// add the remaining elements, plus the character cue, to the previous page
							FNElement *characterCue = [[FNElement alloc] init];
							characterCue.elementType = @"Character";
							characterCue.elementText = [NSString stringWithFormat:@"%@ (CONT'D)", [tmpElements[0] elementText]];
							
							blockHeight += [FNPaginator heightForString:characterCue.elementText font:font maxWidth:[FNPaginator widthForElement:characterCue] lineHeight:lineHeight];
							
							[currentPage addObject:characterCue];
							
							// create the postBreakDialogue
							/*
							if (sentenceIndex < 0) {
								sentenceIndex = 0;
							}
							 */
							if (wordIndex < 0) {
								wordIndex = 0;
							}
							
							NSMutableString *dialogueAfterBreak = [NSMutableString string];
							for (NSInteger z = wordIndex; z < maxWords; z++) {
								[dialogueAfterBreak appendString:words[z]];
								[dialogueAfterBreak appendString:@" "];
							}
							
							FNElement *postBreakDialogue = [[FNElement alloc] init];
							postBreakDialogue.elementType = @"Dialogue";
							postBreakDialogue.elementText = dialogueAfterBreak;
							
							blockHeight += [FNPaginator heightForString:postBreakDialogue.elementText font:font maxWidth:[FNPaginator widthForElement:postBreakDialogue] lineHeight:lineHeight];
							
							[currentPage addObject:postBreakDialogue];
							
							// add remaining elements
							if (blockIndex + 1 < maxTmpElements) {
								for (NSInteger z = blockIndex + 1; z < maxTmpElements; z++) {
									FNElement *e = tmpElements[z];
									[currentPage addObject:tmpElements[z]];
									blockHeight += [FNPaginator heightForString:e.elementText font:font maxWidth:[FNPaginator widthForElement:e] lineHeight:lineHeight];
								}
							}
							
							// set the currentY
							currentY    = blockHeight;
							
							// reset the tmpElements
							tmpElements = [NSMutableArray array];
						}
					}
					else {
						[self.pages addObject:currentPage];
						currentPage = [NSMutableArray array];
						currentY    = blockHeight - spaceBefore;
						
						if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
					}
				}
				else {
					[self.pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					currentY    = blockHeight - spaceBefore;
					blockHeight = 0;
					
					if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
				}
				
			}
			else {
				currentY = blockHeight + currentY;
			}
			
			blockHeight = 0;
			
			// add all the tmp elements to the current page
			for (FNElement *e in tmpElements) {
				[currentPage addObject:e];
			}
			
			// reset the tmp elements holder
			tmpElements = [NSMutableArray array];
			
		}
		
		if ([tmpElements count] > 0) {
			for (FNElement *e in tmpElements) {
				[currentPage addObject:e];
			}
		}
		
		// add the last page of the script to the array
		if ([currentPage count] > 0) {
			[self.pages addObject:currentPage];
			
			if (debug) printf("\n\nPAGE BREAK - - - - - - - - - - - - \n\n");
		}
	}
}



#pragma mark - Helper class methods

+ (CGFloat)spaceBeforeForElement:(FNElement *)element
{
	CGFloat spaceBefore = 0;
	
	NSString *type  = element.elementType;
	NSSet *set      = [NSSet setWithObjects:@"Action", @"General", @"Character", @"Transition", nil];
	
	if ([type isEqualToString:@"Scene Heading"]) {
		spaceBefore = 2.5;
	}
	else if ([set containsObject:type]) {
		spaceBefore = 1.1;
	}
	
	return spaceBefore;
}

+ (NSInteger)leftMarginForElement:(FNElement *)element
{
	NSInteger leftMargin = 0;
	NSString *type = element.elementType;
	
	if ([type isEqualToString:@"Scene Heading"] || [type isEqualToString:@"Action"] || [type isEqualToString:@"General"]) {
		leftMargin  = 106;
	}
	else if ([type isEqualToString:@"Character"]) {
		leftMargin  = 247;
	}
	else if ([type isEqualToString:@"Dialogue"]) {
		leftMargin  = 177;
	}
	else if ([type isEqualToString:@"Parenthetical"]) {
		leftMargin  = 205;
	}
	else if ([type isEqualToString:@"Transition"]) {
		leftMargin  = 106;
	}
	
	return leftMargin;
}

+ (NSInteger)widthForElement:(FNElement *)element
{
	NSInteger width = 0;
	NSString *type  = element.elementType;
	
	if ([type isEqualToString:@"Action"] || [type isEqualToString:@"General"] || [type isEqualToString:@"Scene Heading"] || [type isEqualToString:@"Transition"]) {
		width   = 430;
	}
	else if ([type isEqualToString:@"Character"]) {
		width   = 230;
	}
	else if ([type isEqualToString:@"Dialogue"]) {
		width   = 250;
	}
	else if ([type isEqualToString:@"Parenthetical"]) {
		width   = 212;
	}
	
	return width;
}

/*
 To get the height of a string we need to create a text layout box, and use that to calculate the number
 of lines of text we have, then multiply that by the line height. This is NOT the method Apple describes
 in their docs, but we have to do this because getting the size of the layout box (Apple's recommended
 method) doesn't take into account line height, so text won't display correctly when we try and print.
 */
+ (NSInteger)heightForString:(NSString *)string font:(QUQFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(NSInteger)lineHeight
{
	/*
	 This method won't work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
#if TARGET_OS_IPHONE
	NSTextContainer *textContainer = [[NSTextContainer alloc] init];
	[textContainer setSize:CGSizeMake(maxWidth, MAXFLOAT)];
#else
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(maxWidth, MAXFLOAT)];
#endif
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0.0];
	
	[layoutManager glyphRangeForTextContainer:textContainer];
	
	// get the number of lines
	NSInteger numberOfLines;
	NSInteger index;
	NSInteger numberOfGlyphs = [layoutManager numberOfGlyphs];
	
	NSRange lineRange;
	for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
		[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		index = NSMaxRange(lineRange);
	}
	
	// calculate the height
	NSInteger height = numberOfLines * lineHeight;
	return height;
}

@end
