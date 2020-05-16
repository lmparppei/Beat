//
//  FNPaginator.m
//
//	Copyright © KAPITAN! / Lauri-Matti Parppei
//	Based on FNPaginator, copyright © 2012-2013 Nima Yousefi & John August
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
 
 WORK IN PROGRESS:
 - Check for stylization when pages are broken (italics, bolds etc.)
	This could be done with an instance of ContinuousFountainParser, because FNElement does not have any sort of knowledge of style ranges
 
 Fountain pagination. This is still based on the original Fountain repository file, but totally rewritten from ground up for Beat during COVID-19 isolation.
 
 Original Fountain repository pagination code was totally convoluted had many obvious bugs and stuff that really didn't work in many places. I went out of my way to make my own pagination engine, just to end up with something almost as convoluted.
 
 Maybe it was an important journey - I learned how this actually works and got to spend a nice day coding in my bathrobe. I had two feature scripts that required my attention, but yeah. This is duct-taped together to give somewhat acceptable pagination results when using European page sizes, and now also splits paragraphs into parts.
 
 It doesn't matter - I have the chance to spend my days doing something I'm intrigued by, and probably it makes it less likely that I'll get dementia or other memory-related illness later in life. I don't know.
 
 This might have been pretty unhelpful for anyone stumbling upon this file  some day.
 Try to make something out of it.
 I might be gone but the code lives on.
 
 "Remember the flight
 the bird is mortal"
 (Forough Farrokhzad)
 
 */

#import "FNPaginator.h"
#import "FNScript.h"
#import "FNElement.h"
#import "RegExCategories.h"
#import "Line.h"

#define LINE_HEIGHT 13

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
		bool debug = NO;
		
		NSInteger oneInchBuffer = 72;
		NSInteger maxPageHeight =  pageSize.height - round(oneInchBuffer * 1.1);
		
		if (debug) NSLog(@"Papersize: %f - maxheight %lu", pageSize.height, oneInchBuffer);
		
		NSFont *font = [NSFont fontWithName:@"Courier" size:12];
		//NSInteger lineHeight = font.pointSize * 1.1;
		CGFloat lineHeight = LINE_HEIGHT;
		
		CGFloat spaceBefore;
		CGFloat elementWidth;
		
		NSInteger initialY = 0; // initial starting point on page
		NSInteger currentY = initialY;
		NSMutableArray *currentPage = [NSMutableArray array];
		
		// create a tmp array that will hold elements to be added to the pages
		NSMutableArray *tmpElements = [NSMutableArray array];
		NSInteger maxElements = [self.script.elements count];
		
		NSInteger previousDualDialogueBlockHeight = -1;
		
		NSSet *dialogueBlockTypes = [NSSet setWithObjects:@"Dialogue", @"Parenthetical", nil];
		
		// walk through the elements array
		for (NSInteger i = 0; i < maxElements; i++) {
			// We need to copy this here, not to fuck anything
			FNElement *element  = (self.script.elements)[i];
			
			// If we already handled this element, carry on
			if ([tmpElements containsObject:element]) {
				continue;
			} else [tmpElements removeAllObjects];
			
			// Skip invisible elements
			if ([element.elementType isEqualToString:@"Synopsis"] || [element.elementType isEqualToString:@"Section Heading"] ||
				[element.elementType isEqualToString:@"Boneyard"]) {
				continue;
			}
			
			// Reset Y if the page is empty
			if ([currentPage count] == 0) currentY = initialY;
			
			// catch page breaks immediately
			if ([element.elementType isEqualToString:@"Page Break"]) {
				// close the open page
				[currentPage addObject:element];
				[self.pages addObject:currentPage];
								
				// reset currentPage and the currentY value
				currentPage = [NSMutableArray array];
				currentY    = initialY;
				
				continue;
			}
			
			// get spaceBefore, the leftMargin, and the elementWidth
			spaceBefore         = [FNPaginator spaceBeforeForElement:element];
			elementWidth        = [FNPaginator widthForElement:element];
			
			// get the height of the text
			NSInteger blockHeight    = [FNPaginator heightForString:element.elementText font:font maxWidth:elementWidth lineHeight:lineHeight];
			NSInteger elementHeight = [FNPaginator heightForString:element.elementText font:font maxWidth:elementWidth lineHeight:lineHeight];
			
			// data integrity check
			if (blockHeight <= 0) {
				// height = lineHeight;
				continue;
			}
			NSInteger dialogueBlockHeight = 0;
			
			// only add the space before if we're not at the top of the current page
			if ([currentPage count] > 0) {
				blockHeight += spaceBefore;
				int spaceB = spaceBefore;
				
				if (debug) NSLog(@"   %i  |       [%@]", spaceB, element.elementType);
			}
			
			if (debug) NSLog(@"   %lu  |  %lu  [%@] %@", elementHeight, currentY, element.elementType, [self snippet:element.elementText]);

			
			// Fix to get styling to show up in PDFs. I have no idea.
			if (![element.elementText isMatch:RX(@" $")]) {
				element.elementText = [NSString stringWithFormat:@"%@%@", element.elementText, @""];
			}
			
			NSInteger fullHeight = blockHeight;
						
			// GOING THROUGH ELEMENTS
			
			// Reset dual dialogue
			if (![element.elementType isEqualToString:@"Character"]) previousDualDialogueBlockHeight = -1;
			
			// Handle scene headings
			if ([element.elementType isEqualToString:@"Scene Heading"]) {
				//NSInteger fullHeight = [FNPaginator widthForElement:element];
				[tmpElements addObject:element];

				NSInteger j = i+1;
				FNElement *nextElement;

				while (j < maxElements && ![nextElement.elementText length]) {
					nextElement = (self.script.elements)[j];
					//NSLog(@"/ next: %@", nextElement.elementText);
					j++;
				}
				NSInteger height = [FNPaginator elementHeight:nextElement font:font lineHeight:lineHeight];
				fullHeight += [FNPaginator spaceBeforeForElement:nextElement] + height;
				
				if (nextElement) [tmpElements addObject:nextElement];
				//NSLog(@"/ full height: %lu", fullHeight);
			}
			
			// Handle character. Get whole block.
			else if ([element.elementType isEqualToString:@"Character"] && [self elementExists:i+1]) {
				FNElement *nextElement;
				NSInteger j = i; // Next item index
				
				nextElement = element;
				
				if ([currentPage count]) dialogueBlockHeight = spaceBefore; else dialogueBlockHeight = 0;
				
				do {
					dialogueBlockHeight += [FNPaginator elementHeight:nextElement font:font lineHeight:lineHeight];
					[tmpElements addObject:nextElement];
					
					j++;
					if (j < maxElements) nextElement = (self.script.elements)[j];
				} while (j < maxElements && [dialogueBlockTypes containsObject:nextElement.elementType]);
				
				if (element.isDualDialogue && previousDualDialogueBlockHeight < 0) {
					if (debug) NSLog(@"DUAL: first");
					previousDualDialogueBlockHeight = dialogueBlockHeight;
				}
				else if (element.isDualDialogue && previousDualDialogueBlockHeight > 0) {
					if (previousDualDialogueBlockHeight < dialogueBlockHeight) {
						if (debug) NSLog(@"DUAL: higher // new %lu vs. prev %lu", dialogueBlockHeight, previousDualDialogueBlockHeight);
						dialogueBlockHeight = dialogueBlockHeight - previousDualDialogueBlockHeight;
					} else {
						if (debug) NSLog(@"DUAL: lower // new %lu vs. prev %lu", dialogueBlockHeight, previousDualDialogueBlockHeight);
						dialogueBlockHeight = 0;
					}
				} else {
					// Reset
					previousDualDialogueBlockHeight = -1;
				}
				
				fullHeight = dialogueBlockHeight;
				
			} else {
				[tmpElements addObject:element];
			}
			
			
			// BREAKING ELEMENTS ONTO PAGES
			// Figure out which element went overboard
			if (currentY + fullHeight > maxPageHeight) {
				CGFloat overflow = maxPageHeight - (currentY + fullHeight);

				if (debug) NSLog(@"--- break: %@ (overflow %f) - %f remains on page (at %lu/%lu)", element.elementText, overflow, fullHeight - fabs(overflow), currentY, maxPageHeight);

				// How many rows remain on page
				//NSInteger rows = fabs(overflow) / 12;
				//if (rows == 0) rows = 1;
				
				// If it fits, just squeeze it on this page
				if (fabs(overflow) < lineHeight * 1.5) {
					if (debug) NSLog(@"squeeze %@", element.elementText);
					[currentPage addObjectsFromArray:tmpElements];
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					currentY = 0;
					continue;
				}
				
				// Find out the spiller
				FNElement *spillerElement;

				bool handled = NO;
				
				//Scene heading / action paragraph
				if ([element.elementType isEqualToString:@"Scene Heading"] || [element.elementType isEqualToString:@"Action"]) {
					bool headingBlock = NO;

					if ([element.elementType isEqualToString:@"Scene Heading"]) {
						headingBlock = YES;
						if ([self elementExists:i+1]) spillerElement = (self.script.elements)[i+1];
						else spillerElement = element;
					} else {
						spillerElement = element;
					}
					
					// Some duct tape :----)
					if (headingBlock) {
						// Push to next page for stylistical reasons
						if (fullHeight - fabs(overflow) < lineHeight * 3
							&& fabs(overflow) > lineHeight * 2) {
							handled = YES;
						}
					}
					
					// Split first paragraph scene into two if it's higher than one line
					NSInteger limit = lineHeight;
					NSInteger space = maxPageHeight - currentY;
					
					//if (headingBlock) limit = lineHeight + blockHeight;

					if (fabs(overflow) > limit && space > limit * 2 && !handled) {
						if (debug) NSLog(@"split across pages");
						NSArray *words = [spillerElement.elementText componentsSeparatedByString:@" "];
						NSInteger space = maxPageHeight - currentY;
						
						if (headingBlock) space -= blockHeight;
						
						NSString *text = @"";
						NSString *retain = @"";
						NSString *split = @"";
						
						// Loop through words and count the height
						for (NSString *word in words) {
							text = [text stringByAppendingFormat:@" %@", word];
							FNElement *tempElement = [FNElement elementOfType:@"Action" text:text];
							NSInteger h = [FNPaginator elementHeight:tempElement font:font lineHeight:lineHeight];
							if (h < space) {
								retain = [retain stringByAppendingFormat:@" %@", word];
							} else {
								split = [split stringByAppendingFormat:@" %@", word];
							}
						}
						
						FNElement *prePageBreak = [FNElement elementOfType:@"Action" text:retain];
						FNElement *postPageBreak = [FNElement elementOfType:@"Action" text:split];
						if (debug) NSLog(@"retain: %@ / split %@", retain, split);
						
						// If it's a heading we need special rules
						if (headingBlock) {
							// We had something remain on the original page
							if ([retain length]) {
								[currentPage addObject:element];
								[currentPage addObject:prePageBreak];
								[_pages addObject:currentPage];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:postPageBreak];
								currentY = [FNPaginator elementHeight:postPageBreak font:font lineHeight:lineHeight];
							}
							// Nothing remained, move scene heading to next page
							else {
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								[currentPage addObject:element];
								[currentPage addObject:postPageBreak];
								currentY = fullHeight - spaceBefore; // Remove space from beginning, because this is the first element
							}
						} else {
							[currentPage addObject:prePageBreak];
							[_pages addObject:currentPage];
							currentPage = [NSMutableArray array];
							[currentPage addObject:postPageBreak];
							currentY = [FNPaginator elementHeight:postPageBreak font:font lineHeight:lineHeight];
						}
												
						continue;
						
					} else {
						if (debug) NSLog(@"throw on next: %@", element);
						// Close page and reset
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
					}
				}
				
				// Character spills
				else if ([element.elementType isEqualToString:@"Character"] ) {
					// Figure out which element in dialogue block went over the page limit
					NSInteger dialogueHeight = 0;
					NSInteger blockIndex = -1;
				
					NSInteger remainingSpace = maxPageHeight - currentY;
	
					
					for (FNElement *dElement in tmpElements) {
						blockIndex++;
						NSInteger h = [FNPaginator elementHeight:dElement font:font lineHeight:lineHeight];
						if (currentY + dialogueHeight + h > maxPageHeight) { spillerElement = dElement; break; }
						else { dialogueHeight += h; }
					}
					
					// If we got stuck in parenthetical, throw the whole block on the next page
					if ([spillerElement.elementType isEqualToString:@"Parenthetical"] && blockIndex < 2) {
						if (debug) NSLog(@" // parenthetical to next page");
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
					}
				
					// Squeeze this element on current page
					else if (fabs(overflow) <= lineHeight) {
						if (debug) NSLog(@" // squeeze");
						[currentPage addObjectsFromArray:tmpElements];
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
						currentY = 0;
						continue; // Don't let the loop take care of the tmp buffer here
					}
					else if (remainingSpace > lineHeight * 2) {
						if (debug) NSLog(@" // wrap");
						if ([spillerElement.elementType isEqualToString:@"Dialogue"]) {
							// Break into sentences
							NSMutableArray *sentences = [NSMutableArray arrayWithArray:[spillerElement.elementText matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
							if (![sentences count] && [spillerElement.elementText length]) [sentences addObject:spillerElement.elementText];
							
							NSString *text = @"";
							NSString *retain = @"";
							NSString *split = @"";
							
							for (NSString *sentence in sentences) {
								text = [text stringByAppendingFormat:@" %@", sentence];
								FNElement *tempElement = [FNElement elementOfType:@"Dialogue" text:text];
								NSInteger h = [FNPaginator elementHeight:tempElement font:font lineHeight:lineHeight];
								
								// We need to substract other dialogue block heights from here
								NSInteger space = maxPageHeight - currentY - dialogueHeight;
								if (debug) NSLog(@"remaining space: %lu", space);

								if (h < space) {
									retain = [retain stringByAppendingFormat:@" %@", sentence];
								} else {
									split = [split stringByAppendingFormat:@" %@", sentence];
								}
							}
							if (debug) NSLog(@" -----> retain: %@ / split %@", retain, split);
							
							// If we have something to retain, do it, otherwise just break to next page
							if ([retain length] > 0) {
								for (NSInteger d = 0; d < blockIndex; d++) {
									FNElement *preBreak = [FNElement elementOfType:[tmpElements[d] elementType] text:[tmpElements[d] elementText]];
									[currentPage addObject:preBreak];
								}
								// Add on the previous page
								FNElement *preDialogue = [FNElement elementOfType:@"Dialogue" text:retain];
								FNElement *preMore = [FNElement elementOfType:@"More" text:@"(MORE)"];
								
								[currentPage addObject:preDialogue];
								[currentPage addObject:preMore];
								[self.pages addObject:currentPage];
								currentPage = [NSMutableArray array];

								// Add the remaining stuff on the next page
								FNElement *postCue = [FNElement elementOfType:@"Character" text:[element.elementText stringByAppendingString:@" (CONT'D)"]];
								FNElement *postDialogue = [FNElement elementOfType:@"Dialogue" text:split];
								[currentPage addObject:postCue];
								[currentPage addObject:postDialogue];
								
								currentY = 0;
								currentY += [FNPaginator elementHeight:postCue font:font lineHeight:lineHeight];
								currentY += [FNPaginator elementHeight:postDialogue font:font lineHeight:lineHeight];

								// Add possible remaining dialogue elements
								if (blockIndex + 1 > [tmpElements count]) continue;
								for (NSInteger d = blockIndex + 1; d < [tmpElements count]; d++) {
									FNElement *postBreak = [FNElement elementOfType:[tmpElements[d] elementType] text:[tmpElements[d] elementText]];
									currentY += [FNPaginator elementHeight:postBreak font:font lineHeight:lineHeight];
									[currentPage addObject:postBreak];
								}

								// Don't let this loop handle the buffer
								continue;
							} else {
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
							}

						} else {
							// Parenthetical spills
							if ([spillerElement.elementType isEqualToString:@"Parenthetical"] && blockIndex > 1) {
								// Add the preceeding elements
								for (NSInteger d = 0; d < blockIndex; d++) {
									FNElement *dElement = tmpElements[d];
									[currentPage addObject:dElement];
								}
								
								// Add (more) after the dialogue
								[currentPage addObject:[FNElement elementOfType:@"More" text:@"(MORE)"]];
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								
								FNElement *postCue = [FNElement elementOfType:@"Character" text:[element.elementText stringByAppendingString:@" (CONT'D)"]];
								[currentPage addObject:postCue];
								[currentPage addObject:spillerElement];
								
								// Count heights
								currentY = 0;
								currentY += [FNPaginator elementHeight:postCue font:font lineHeight:lineHeight];
								currentY += [FNPaginator elementHeight:spillerElement font:font lineHeight:lineHeight];
								
								// Add the rest of the stuff
								for (NSInteger d = blockIndex + 1; d < tmpElements.count; d++) {
									FNElement *dElement = tmpElements[d];
									currentY += [FNPaginator elementHeight:dElement font:font lineHeight:lineHeight];
									[currentPage addObject:dElement];
								}
								
								// Don't let the loop take care of the buffered elements
								continue;
							}
						}
						
					// Otherwise push it on the next page
					} else {
					
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
					}
				}
				else if ([element.elementType isEqualToString:@"Action"]) {
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
				} else {
					// Whatever, let's just push this element on the next page
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
				}
				
				//blockHeight = 0;
				currentY = 0;
			}
			
			// Add remaining elements
			for (FNElement *el in tmpElements) {
				NSInteger h = [FNPaginator elementHeight:el font:font lineHeight:lineHeight];
				
				if (previousDualDialogueBlockHeight < 0) {
					currentY += h;
					if ([currentPage count] > 0) { currentY += [FNPaginator spaceBeforeForElement:el]; }
				} else {
					// If this is double dialogue, let's add dialogue block height.
					// If this one was higher, its height difference is added on top of the previous
					if (debug) NSLog(@"       --- (double dialogue: %@)", element.elementText);
					currentY += dialogueBlockHeight;
				}
				
				if (debug)  NSLog(@"        --- %lu [%@]", currentY, el.elementType);
				[currentPage addObject:el];
			}
			//[currentPage addObjectsFromArray:tmpElements];
			//currentY += fullHeight;
		}
		
		[_pages addObject:currentPage];
	}
}


- (NSString *)snippet:(NSString*)string {
	if ([string length] > 25) {
		NSRange range = NSMakeRange(0,25);
		return [string substringWithRange:range];
	} else {
		return string;
	}
}

#pragma mark - Helper class methods
	
- (bool)elementExists:(NSInteger)i {
	if (i < self.script.elements.count) return YES; else return NO;
}

+ (CGFloat)lineHeight {
	return LINE_HEIGHT;
}
+ (CGFloat)spaceBeforeForElement:(FNElement *)element
{
	CGFloat spaceBefore = 0;
	
	NSString *type  = element.elementType;
	NSSet *set      = [NSSet setWithObjects:@"Action", @"General", @"Character", @"Transition", nil];
	
	if ([type isEqualToString:@"Scene Heading"]) {
		//spaceBefore = 3;
		spaceBefore = 33;
	}
	else if ([set containsObject:type]) {
		//spaceBefore = 1.1;
		spaceBefore = LINE_HEIGHT;
	}
	
	return spaceBefore;
}

+ (NSInteger)widthForElementType:(NSString*)type {
	return [FNPaginator widthForElement:[FNElement elementOfType:type text:@""]];
}

+ (CGFloat)elementHeight:(FNElement *)element font:(NSFont*)font lineHeight:(CGFloat)lineHeight {
	return [FNPaginator heightForString:element.elementText font:font maxWidth:[FNPaginator widthForElement:element] lineHeight:lineHeight];
}

+ (NSInteger)widthForElement:(FNElement *)element
{
	NSInteger width = 0;
	NSString *type  = element.elementType;
	
	if ([type isEqualToString:@"Action"] || [type isEqualToString:@"General"] || [type isEqualToString:@"Scene Heading"] || [type isEqualToString:@"Transition"]) {
		width   = 430;
	}
	else if ([type isEqualToString:@"Character"]) {
		width   = 180;
	}
	else if ([type isEqualToString:@"Dialogue"]) {
		width   = 217;
	}
	else if ([type isEqualToString:@"Parenthetical"]) {
		width   = 210;
	}
	
	return width;
}

/*
 To get the height of a string we need to create a text layout box, and use that to calculate the number
 of lines of text we have, then multiply that by the line height. This is NOT the method Apple describes
 in their docs, but we have to do this because getting the size of the layout box (Apple's recommended
 method) doesn't take into account line height, so text won't display correctly when we try and print.
 */
+ (NSInteger)heightForString:(NSString *)string font:(NSFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight
{
	/*
	 This method won't work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	
	if ([string length] < 1) return lineHeight;
	
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

#pragma mark - Beat helper methods

+ (CGFloat)spaceBeforeForLine:(Line*)line {
	if (line.type == heading) return [self spaceBeforeForElement:[FNElement elementOfType:@"Scene Heading" text:line.string]];
	else if (line.type == character) return LINE_HEIGHT;
	else if (line.type == dialogue) return 0;
	else if (line.type == parenthetical) return 0;
	else if (line.type == action) return LINE_HEIGHT;
	else return LINE_HEIGHT;
}

@end
