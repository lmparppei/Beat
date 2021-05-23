//
//  FountainPaginator.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 WORK IN PROGRESS.

 This is very loosely based on the original FNPaginator code, with heavy
 modifications to the whole logic behind it, and rewritten to use the
 Line class driving ContinuousFountainParser.
  
 Original Fountain repository pagination code was totally convoluted and had
 many obvious bugs and stuff that really didn't work in many places.
 I went out of my way to make my own pagination engine, just to end up with
 something almost as convoluted.
 
 Maybe it was an important journey - I learned how this actually works and
 got to spend a nice day coding in my bathrobe. I had two feature scripts that
 required my attention, but yeah. This is duct-taped together to give somewhat
 acceptable pagination results when using European page sizes, and now also
 splits paragraphs into parts.
 
 It doesn't matter - I have the chance to spend my days doing something I'm
 intrigued by, and probably it makes it less likely that I'll get dementia or
 other memory-related illness later in life. I don't know.
 
 I have found the fixed values with goold old trial & error. As we are using a
 WebView (which is now deprecated, btw, so I'm fucked again) rendering HTML
 file, the pixel coordinates do not match AT ALL. There is a boolean value
 to check whether we're paginating on a US Letter or on the only real
 paper size, used by the rest of the world (A4).
 
 The current iteration has live pagination stuff built in. The goal is to have
 the class only paginate from changed indices. I've made some experiments to allow
 that, but for now it does not work at all.
 
 This might have been pretty unhelpful for anyone stumbling upon this file some day.
 Try to make something out of it.
 
 NOTE NOTE NOTE:
 - Element widths are 80% of the CSS size. I don't know why, but this
   is the only way I got them to match with the real WebKit sizing.
 - There is a specific splitting / joining logic built into the Line class. Joining lines
   happens in the parser, while SPLITTING is taken care of here. This happens in a
   very convoluted manner, with differing logic for dialogue and actions, but
   I'm looking into it.
 
 Remember the flight
 the bird may die
 (Forough Farrokhzad)
 
 */

#import "FountainPaginator.h"
#import "Line.h"
#import "RegExCategories.h"
#import "BeatPaperSizing.h"

#define LINE_HEIGHT 12.5

@interface FountainPaginator ()

@property (weak, nonatomic) NSDocument *document;
@property (strong, nonatomic) NSArray *script;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSString *textCache;
@property bool paginating;
@property bool A4;
@property BeatFont *font;

@property NSMutableIndexSet *changedIndices;

// WIP
@property (nonatomic) bool livePagination;

@end

@implementation FountainPaginator

- (id)initWithScript:(NSArray *)elements
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	return self;
}
- (id)initWithScript:(NSArray *)elements document:(NSDocument*)document
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_document = document;
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	return self;
}

- (id)initLivePagination:(id<BeatPaginatorDelegate>)delegate {
	self = [super init];
	if (self) {
		_delegate = delegate;
		_font = [BeatFont fontWithName:@"Courier" size:12];
		return self;
	} else {
		return nil;
	}
}

- (id)initForLivePagination:(NSDocument*)document {
	self = [super init];
	if (self) {
		_pages = [NSMutableArray array];
		_script = [NSArray array];
		_livePagination = YES;
		_pageBreaks = [NSMutableArray array];
		_document = document;
		_changedIndices = [NSMutableIndexSet indexSet];
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	return self;
}
- (id)initForLivePagination:(NSDocument*)document withElements:(NSArray*)elements {
	self = [super init];
	if (self) {
		_pages = [NSMutableArray array];
		_script = elements;
		_livePagination = YES;
		_pageBreaks = [NSMutableArray array];
		_document = document;
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	return self;
}
- (id)initWithScript:(NSArray *)elements paperSize:(CGSize)paperSize
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_paperSize = paperSize;
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	return self;
}

// Experimental new live pagination

- (NSArray*)findSafeLineFrom:(Line*)line page:(NSMutableArray*)page {
	NSInteger pageNumber = [_pages indexOfObject:page];
	
	for (NSInteger pgIndex = pageNumber; pgIndex >0; pgIndex--) {
		NSMutableArray *page = _pages[pgIndex];
		
		NSInteger indexOnPage = [page indexOfObject:line];
		if (indexOnPage == NSNotFound) indexOnPage = page.count - 1;
		
		if (index >= 0) {
			for (NSInteger lnIndex = indexOnPage; lnIndex >= 0; lnIndex--) {
				Line *line = page[lnIndex];
				if (!line.unsafeForPageBreak) return @[page, line];
			}
		}
	}
	
	return nil;
}
- (void)addChangeAt:(NSRange)range {
	[_changedIndices addIndexesInRange:range];
}

- (void)livePaginationFor:(NSArray*)script changeAt:(NSRange)range {
	// Normal pagination
	//_paginating = NO;
	

	[_changedIndices addIndex:range.location];
	
	/*
	@synchronized (self) {
		self.script = script;
		_paginating = YES;
		[self paginateFromIndex:0 currentPage:nil];
	}
	 */
	
	@synchronized (self) {
		self.script = script;
		_paginating = YES;
		
		_pages = [NSMutableArray array];
		_pageBreaks = [NSMutableArray array];

		[self paginateFromIndex:0 startFromLine:nil page:nil];
		
		/*
		// For those who come after
		// This is VERY close from working, I just can't wrap my head around it
		 
		NSArray *paginationStart;
				
		// Find current line based on the index
		for (NSMutableArray *page in _pages) {
			for (Line* line in page) {
				if (NSLocationInRange(_changedIndices.firstIndex, line.textRange)) {
					paginationStart = [self findSafeLineFrom:line page:page];
				}
			}
		}
		
		if (paginationStart) {
			NSMutableArray *page = paginationStart[0];
			Line *line = paginationStart[1];
			
			NSInteger pageIndex = [_pages indexOfObject:page];
			
			if (pageIndex > 0) {
				_pages = [_pages subarrayWithRange:(NSRange){0, pageIndex}].mutableCopy;
				_pageBreaks = [_pageBreaks subarrayWithRange:(NSRange){0, pageIndex + 1}].mutableCopy;
				
				[self paginateFromIndex:_changedIndices.firstIndex startFromLine:line page:page];
			} else {
				_pages = [NSMutableArray array];
				_pageBreaks = [NSMutableArray array];
				[self paginateFromIndex:0 startFromLine:line page:page];
			}
		} else {
			_pages = [NSMutableArray array];
			_pageBreaks = [NSMutableArray array];
			[self paginateFromIndex:0 startFromLine:nil page:nil];
		}
		 */
		
		_changedIndices = [NSMutableIndexSet indexSet]; 
	}

}

- (NSArray *)pageAtIndex:(NSUInteger)index
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if (self.pages.count == 0) {
		[self paginate];
	}
	
	// Make sure we don't try and access an index that doesn't exist
	if ([self.pages count] == 0 || (index > self.pages.count - 1)) {
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

/*

 You, who shall resurface following the flood
 In which we have perished,
 Contemplate —
 When you speak of our weaknesses,
 Also the dark time
 That you have escaped.
 
*/


- (void)paginate {
	[self paginateFromIndex:0 startFromLine:nil page:nil];
}
- (void)paginateFromIndex:(NSInteger)fromIndex startFromLine:(Line*)firstLine page:(NSMutableArray*)firstPage
{
	// paginationStart is an
	
	if (!self.script.count) return;
	
	if (_document) {
		NSPrintInfo *printInfo = [_document.printInfo copy];
		printInfo = [BeatPaperSizing setMargins:printInfo];
		
		// Check paper size
		if (printInfo.paperSize.width > 595) _A4 = NO;
		_A4 = YES;

		CGFloat w = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin;
		CGFloat h = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin;
		
		_paperSize = CGSizeMake(w, h);
	} else {
		_paperSize = CGSizeMake(595, 821);
	}
	
	/*
	if (self.document) {
		// Get paper size from the document
		CGFloat w = _document.printInfo.paperSize.width - _document.printInfo.leftMargin - _document.printInfo.rightMargin;
		CGFloat h = _document.printInfo.paperSize.height - _document.printInfo.topMargin - _document.printInfo.bottomMargin;
		_paperSize = CGSizeMake(w, h);
		
		if (self.livePagination) NSLog(@"live: %f", h);
		else NSLog(@"print %f", h);
	} else {
		NSLog(@"hello");
		// US letter paper size is 8.5 x 11 (in pixels)
		_paperSize = CGSizeMake(612, 792);
	}
	 */
	
	bool debug = NO;

	NSMutableArray *currentPage = [NSMutableArray array];
	
	NSInteger initialY = 0; // initial starting point on page
	NSInteger currentY = initialY;
	
	NSInteger oneInchBuffer = 72;
	NSInteger maxPageHeight = _paperSize.height - round(oneInchBuffer * 1.25);
		
	//NSInteger lineHeight = font.pointSize * 1.1;
	CGFloat lineHeight = LINE_HEIGHT;
	
	NSInteger firstIndex = 0;
	
	if (firstPage) {
		NSInteger lineIndex = [firstPage indexOfObject:firstLine];
		firstIndex = firstLine.position;
		
		for (int e = 0; e < lineIndex; e++) {
			Line *line = firstPage[e];
			currentY += [FountainPaginator spaceBeforeForLine:line];
			currentY += [self elementHeight:line lineHeight:LINE_HEIGHT];
			[currentPage addObject:line];
		}
	}
	
	@autoreleasepool {
		
		CGFloat spaceBefore;
		CGFloat elementWidth;
				
		// create a tmp array that will hold elements to be added to the pages
		NSMutableArray *tmpElements = [NSMutableArray array];
		NSInteger maxElements = self.script.count;
		
		NSInteger previousDualDialogueBlockHeight = -1;
		
		// walk through the elements array
		for (NSInteger i = 0; i < maxElements; i++) {
			if (!_paginating && _livePagination) {
				// An experiment in canceling background-thread pagination
				[self cancel];
				return;
			}
			
			Line *element  = (self.script)[i];
			
			// Skip element if it's not in the specified range
			if (firstIndex > 0 && firstIndex > element.position + element.string.length) {
				continue;
			}
			
			// If we already handled this element, carry on
			if ([tmpElements containsObject:element]) {
				continue;
			} else [tmpElements removeAllObjects];
			
			// Skip invisible elements
			if (element.isInvisible || element.type == empty) continue;
			
			// If this is the FIRST page, add a break to mark for the end of title page and beginning of document
			if (_pageBreaks.count == 0) [self pageBreak:element position:0];
			
			// Reset Y if the page is empty
			if ([currentPage count] == 0) currentY = initialY;
			
			// catch page breaks immediately
			if (element.type == pageBreak) {
				// close the open page
				[currentPage addObject:element];
				[self.pages addObject:currentPage];

				[self pageBreak:element position:-1];
				
				// reset currentPage and the currentY value
				currentPage = [NSMutableArray array];
				currentY    = initialY;
				
				continue;
			}
			
			// Catch wrong parsing.
			// We SHOULD NOT have orphaned dialogue. This can happen with non-forced text.
			if (element.type == dialogue && element.string.length == 0) continue;
			
			// get spaceBefore, the leftMargin, and the elementWidth
			spaceBefore         = [FountainPaginator spaceBeforeForLine:element];
			elementWidth        = [self widthForElement:element];
			
			// get the height of the text
			NSInteger blockHeight    = [FountainPaginator heightForString:element.stripFormattingCharacters font:_font maxWidth:elementWidth lineHeight:lineHeight];
			
			// data integrity check
			if (blockHeight <= 0) {
				// height = lineHeight;
				continue;
			}
			
			NSInteger dialogueBlockHeight = 0;
			
			// only add the space before if we're not at the top of the current page
			if (currentPage.count > 0) {
				blockHeight += spaceBefore;
			}
			
			// Fix to get styling to show up in PDFs. I have no idea.
			if (![element.string isMatch:RX(@" $")]) {
				element.string = [NSString stringWithFormat:@"%@%@", element.string, @""];
			}
			
			NSInteger fullHeight = blockHeight;
						
			// ### LOOP THROUGH ELEMENTS
			
			// Reset dual dialogue
			if (element.type != dualDialogueCharacter) previousDualDialogueBlockHeight = -1;
			
			// Handle scene headings
			if (element.type == heading) {
				//NSInteger fullHeight = [FNPaginator widthForElement:element];
				[tmpElements addObject:element];

				NSInteger j = i+1;
				Line *nextElement;

				while (j < maxElements && ![nextElement.stripFormattingCharacters length]) {
					nextElement = (self.script)[j];
					j++;
				}
				NSInteger height = [self elementHeight:nextElement lineHeight:lineHeight];
				fullHeight += [FountainPaginator spaceBeforeForLine:nextElement] + height;
				
				if (nextElement) [tmpElements addObject:nextElement];
			}
			
			// Handle character. Get whole block.
			// Welcome to a world of pain.
			else if ((element.type == character || element.type == dualDialogueCharacter) && [self elementExists:i + 1]) {
				/*
				 // Ideas to consider
				 NSArray *dialogueBlock = [self dialogueBlockFor:element];
				 
				 // If current page already has elements, take margin into account in the height
				 if (currentPage.count) dialogueBlockHeight = spaceBefore; else dialogueBlockHeight = 0;

				 dialogueBlockHeight += [self heightForDialogueBlock:dialogueBlock];
				 
				 // We need to figure out which element spills in either of the blocks
				 [self splitDialogue:dialogueBlock ...];
				 NSArray *dialogueSeparated = [self separateDualDialogue:dialogueBlock];
				 Line *spillerElement = [self findDialogueSpiller:dialogueSeparated[0]];
				 
				 [tmpElements addObjectsFromArray:dialogueBlock];

				 */
				
				bool isDualDialogue = NO;
				if (element.type == dualDialogueCharacter) isDualDialogue = YES;
								
			
				// If current page already has elements, take margin into account in the height
				if (currentPage.count) dialogueBlockHeight = spaceBefore; else dialogueBlockHeight = 0;
				
				
				
				 Line *nextElement;
				 NSInteger j = i; // Next item index
				 nextElement = element;

				// Catch elements in the dialogue block and calculate the height
				do {
					dialogueBlockHeight += [self elementHeight:nextElement lineHeight:lineHeight];
					[tmpElements addObject:nextElement];
					
					j++;
					if (j < maxElements) nextElement = (self.script)[j];
				} while (j < maxElements && (
					(nextElement.isDialogueElement && !isDualDialogue) ||
					(nextElement.isDualDialogueElement && isDualDialogue)
				));
				
				// Check if there is an upcoming dual dialogue block
				if (element.nextElementIsDualDialogue) {
					previousDualDialogueBlockHeight = dialogueBlockHeight;
				}
				
				// OR if the current block is the one we've been waiting for
				else if (element.type == dualDialogueCharacter) {
					// If the previous dialogue block was lower in height than the current one,
					// we'll substract to get the height difference and add it to the total page height later
					if (previousDualDialogueBlockHeight < dialogueBlockHeight) {
						dialogueBlockHeight = dialogueBlockHeight - previousDualDialogueBlockHeight;
					}
					else dialogueBlockHeight = 0;
				}
				else {
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

				// How many rows remain on page
				//NSInteger rows = fabs(overflow) / 12;
				//if (rows == 0) rows = 1;
				
				// If it fits, just squeeze it on this page
				if (fabs(overflow) < lineHeight * 1.5) {
					// This wouldn't be needed with the new dialogue block system
					if (element.nextElementIsDualDialogue) {
						// We still have elements we have to handle, but this block WOULD fit on this page, however.
						// Let's just continue with our loop.
						[currentPage addObjectsFromArray:tmpElements];
						continue;
					}
					
					[currentPage addObjectsFromArray:tmpElements];
					
					[_pages addObject:currentPage];
					
					// Add page break for live pagination (-1 means the break is AFTER the element)
					[self pageBreak:[tmpElements lastObject] position:-1];
					
					currentPage = [NSMutableArray array];
					currentY = 0;
					continue;
				}
				
				// Find out the spiller
				Line *spillerElement;
				
				bool handled = NO;
				
				#pragma mark Split scene heading & paragraph
				
				if (element.type == heading || element.type == action) {
					bool headingBlock = NO;

					if (element.type == heading) {
						headingBlock = YES;
						if ([self elementExists:i+1]) spillerElement = (self.script)[i+1];
						else spillerElement = element;
					} else {
						spillerElement = element;
					}
					
					// Some duct tape :----)
					if (headingBlock) {
						// Push to next page if it would be only 1 line or something
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
						NSArray *words = [spillerElement.stripFormattingCharacters componentsSeparatedByString:@" "];
						NSInteger space = maxPageHeight - currentY;
						
						if (headingBlock) space -= blockHeight;
						
						NSString *text = @"";
						NSString *retain = @"";
						NSString *split = @"";
						
						CGFloat breakPosition = 0;
						
						// Loop through words and count the height
						int wIndex = 0;
						for (NSString *word in words) {
							if (wIndex == 0) text = [text stringByAppendingFormat:@"%@", word];
							else text = [text stringByAppendingFormat:@" %@", word];
							
							// FNElement *tempElement = [FNElement elementOfType:@"Action" text:text];
							Line *tempElement = [[Line alloc] initWithString:text type:action];
							NSInteger h = [self elementHeight:tempElement lineHeight:lineHeight];
							if (h < space) {
								breakPosition = h;
								if (wIndex == 0) retain = [retain stringByAppendingFormat:@"%@", word];
								else retain = [retain stringByAppendingFormat:@" %@", word];
							} else {
								split = [split stringByAppendingFormat:@" %@", word];
							}
						}
						
						// WIP/NB: We should make the Line return two Line elements after split instead of this messy shit
						NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
						retain = splitElements[0];
						split = splitElements[1];
						 
						// Let's create character indexes for these virtual elements, too
						Line *prePageBreak = [Line withString:retain type:action pageSplit:YES];
						prePageBreak.position = spillerElement.position;
						prePageBreak.changed = spillerElement.changed; // Inherit changes
						
						Line *postPageBreak = [Line withString:split type:action pageSplit:YES];
						postPageBreak.position = prePageBreak.position + prePageBreak.string.length;
						postPageBreak.changed = spillerElement.changed; // Inherit changes
												
						// If it's a heading we need special rules
						if (headingBlock) {
							// We had something remain on the original page
							if ([retain length]) {
								[currentPage addObject:element];
								[currentPage addObject:prePageBreak];
								[_pages addObject:currentPage];
								
								// Add page break for live pagination
								[self pageBreak:spillerElement position:breakPosition];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:postPageBreak];
								currentY = [self elementHeight:postPageBreak lineHeight:lineHeight];
							}
							// Nothing remained, move whole scene heading to next page
							else {
								[_pages addObject:currentPage];
								
								// Page break for live pagination
								[self pageBreak:element position:0];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:element];
								[currentPage addObject:postPageBreak];
								currentY = fullHeight - spaceBefore; // Remove space from beginning, because this is the first element
							}
						} else {
							[currentPage addObject:prePageBreak];
							[_pages addObject:currentPage];
							
							// Add page break info (for live pagination if in use)
							[self pageBreak:spillerElement position:breakPosition];
							
							currentPage = [NSMutableArray array];
							[currentPage addObject:postPageBreak];
							currentY = [self elementHeight:postPageBreak lineHeight:lineHeight];
						}
												
						continue;
						
					} else {
						if (debug) NSLog(@"throw on next: %@", element.string);
												
						// Close page and reset
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];

						// Add page break info (for live pagination if in use)
						[self pageBreak:element position:0];
					}
				}
				
				#pragma mark Split dialogue
				else if (element.type == character || element.type == dualDialogueCharacter) {
					// Figure out which element in dialogue block went over the page limit
					NSInteger dialogueHeight = 0;
					NSInteger blockIndex = -1;
				
					NSInteger remainingSpace = maxPageHeight - currentY;
				
					/*
					// This is the new system. It kind of works, already.
					// The splitDialogue: method needs work to really take it into action.
					 
					NSMutableArray *retainedLines = [NSMutableArray array];
					NSMutableArray *nextPageLines = [NSMutableArray array];
					
					Line *pageBreakElement;
					NSInteger pageBreakPosition = 0;
					
					NSArray *dialogueBlock = [self dialogueBlockFor:element];
					NSInteger dialogueH = [self heightForDialogueBlock:dialogueBlock];
					
					if (labs(remainingSpace - dialogueH) <= LINE_HEIGHT) {
						[currentPage addObjectsFromArray:dialogueBlock];
						[_pages addObject:currentPage];
						
						currentPage = [NSMutableArray array];
						currentY = 0;
						
						// Add page break info (for live pagination if in use)
						[self pageBreak:spillerElement position:-1];
						continue; // Don't let the loop take care of the tmp buffer here
					}
					
					// Normal, single dialogue
					if (!element.nextElementIsDualDialogue) {
						NSLog(@"splitting single dialogue");
						Line *spillEl = [self findDialogueSpiller:dialogueBlock remainingSpace:remainingSpace];
									
						NSDictionary *split = [self splitDialogue:dialogueBlock spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:dialogueBlock]];
						
						if ([(NSArray*)split[@"retained"] count]) {
							[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
							
							pageBreakElement = (Line*)split[@"page break item"];
							pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
							
							[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
						} else {
							[nextPageLines addObjectsFromArray:dialogueBlock];
						}
					}
					// Split dual dialogue (this is a bit more complicated)
					else if (element.nextElementIsDualDialogue) {
						NSArray *dual = [self separateDualDialogue:dialogueBlock];
						
						bool leftSideFits = NO;
						bool rightSideFits = NO;
						
						Line *spillEl = [self findDialogueSpiller:dual[0] remainingSpace:remainingSpace];
						Line *spillEl2 = [self findDialogueSpiller:dual[1] remainingSpace:remainingSpace];
					
						if (!spillEl) leftSideFits = YES;
						if (!spillEl2) rightSideFits = YES;
												
						NSDictionary *split;
						
						if (leftSideFits && !rightSideFits) {
							// Left side fits, split right side
							split = [self splitDialogue:dual[1] spiller:spillEl2 remainingSpace:remainingSpace height:[self heightForDialogueBlock:dual[1]]];
							
							// If there is something to retain, do it, otherwise just push everything on the next page
							if ([(NSArray*)split[@"retained"] count]) {
								[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
								[retainedLines addObjectsFromArray:dual[0]];
								
								pageBreakElement = (Line*)split[@"page break item"];
								pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
								
								[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
							} else {
								[nextPageLines setArray:dialogueBlock];
							}
						}
						else if (!leftSideFits && rightSideFits) {
							// Right side firts, split left side
							
							split = [self splitDialogue:dual[0] spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:dual[0]]];
							
							// If there is something to retain, do it, otherwise just push everything on the next page
							if ([(NSArray*)split[@"retained"] count]) {
								[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
								[retainedLines addObjectsFromArray:dual[1]];
								
								pageBreakElement = (Line*)split[@"page break item"];
								pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
								
								[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
							} else {
								[nextPageLines setArray:dialogueBlock];
							}
						}
						else if (!leftSideFits && !rightSideFits) {
							// Split BOTH dialogue blocks
							NSArray *leftDialogue = dual[0];
							NSArray *rightDialogue = dual[1];
							
							NSDictionary *splitLeft = [self splitDialogue:leftDialogue spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:leftDialogue]];
							NSDictionary *splitRight = [self splitDialogue:rightDialogue spiller:spillEl2 remainingSpace:remainingSpace height:[self heightForDialogueBlock:rightDialogue]];
							
							// Figure out where to put the actual page break
							NSArray *retainLeft = (NSArray*)splitLeft[@"retained"];
							NSArray *retainRight = (NSArray*)splitRight[@"retained"];
							NSArray *nextPageLeft = (NSArray*)splitLeft[@"next page"];
							NSArray *nextPageRight = (NSArray*)splitRight[@"next page"];
							
							//NSInteger leftHeight = [self heightForDialogueBlock:retainLeft];
							//NSInteger rightHeight = [self heightForDialogueBlock:retainRight];

							// If both sides have somethign to retain, do it
							if (retainLeft.count && retainRight.count) {
								[retainedLines addObjectsFromArray:retainLeft];
								[retainedLines addObjectsFromArray:retainRight];
								
								[nextPageLines addObjectsFromArray:nextPageLeft];
								[nextPageLines addObjectsFromArray:nextPageRight];
							} else {
								[nextPageLines setArray:dialogueBlock];
							}
						}
						
						// For some reason, this information is lost in the rain, so we'll reset it, just in case
						if (element.nextElementIsDualDialogue) {
							Line* firstLine = (Line*)retainedLines.firstObject;
							firstLine.nextElementIsDualDialogue = YES;
						}
					}
					
					// Add objects on current page
					[currentPage addObjectsFromArray:retainedLines];
					[_pages addObject:currentPage];
					
					// Add page break for live pagination
					[self pageBreak:pageBreakElement position:pageBreakPosition];
					
					currentPage = [NSMutableArray array];
					[currentPage addObjectsFromArray:nextPageLines];
					currentY = [self heightForDialogueBlock:nextPageLines];
										
					// Ignore the rest of the block
					[tmpElements setArray:dialogueBlock];
					
					continue;
					*/
										
					for (Line *dElement in tmpElements) {
						blockIndex++;
						NSInteger h = [self elementHeight:dElement lineHeight:lineHeight];
						if (currentY + dialogueHeight + h > maxPageHeight) { spillerElement = dElement; break; }
						else { dialogueHeight += h; }
					}
					
					// If we got stuck in first parenthetical, throw the whole block on the next page
					if (((spillerElement.type == parenthetical || spillerElement.type == dualDialogueParenthetical) && blockIndex < 2) || spillerElement.type == character) {
						// ALERT: CHECK THIS

						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
						
						// Add page break info
						[self pageBreak:element position:0];
					}
				
					// Squeeze this element on current page
					else if (fabs(overflow) <= lineHeight) {
						// New system:
						// [currentPage addObjectsFromArray:dialogueBlock];
						
						[currentPage addObjectsFromArray:tmpElements];
						[_pages addObject:currentPage];
						
						currentPage = [NSMutableArray array];
						currentY = 0;
						
						// Add page break info (for live pagination if in use)
						[self pageBreak:spillerElement position:-1];


						continue; // Don't let the loop take care of the tmp buffer here
					}
					else if (remainingSpace > lineHeight * 2) {
						if (spillerElement.type == dialogue || spillerElement.type == dualDialogueCharacter) {
							// Break into sentences
							NSString *stripped = spillerElement.stripFormattingCharacters;
							NSMutableArray *sentences = [NSMutableArray arrayWithArray:[stripped matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
							if (!sentences.count && stripped.length) [sentences addObject:stripped];
							
							NSString *text = @"";
							NSString *retain = @"";
							NSString *split = @"";
							CGFloat breakPosition = 0;
							
							int sIndex = 0;
							for (NSString *rawSentence in sentences) {
								NSString *sentence = [rawSentence stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
								if (sIndex == 0) text = [text stringByAppendingFormat:@"%@", sentence];
								else text = [text stringByAppendingFormat:@" %@", sentence];
								
								Line *tempElement = [[Line alloc] initWithString:text type:dialogue];
								
								NSInteger h = [self elementHeight:tempElement lineHeight:lineHeight];
								
								// We need to substract other dialogue block heights from here
								NSInteger space = maxPageHeight - currentY - dialogueHeight;

								if (h < space) {
									breakPosition = h;
									if (sIndex == 0) retain = [retain stringByAppendingFormat:@"%@", sentence];
									else retain = [retain stringByAppendingFormat:@" %@", sentence];
								} else {
									split = [split stringByAppendingFormat:@" %@", sentence];
								}
								
								sIndex++;
							}
							
							NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
							retain = splitElements[0];
							split = splitElements[1];
							
							// Trim split text
							retain = [retain stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
							split = [split stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
							
							// If we have something to retain, do it, otherwise just break to next page
							if (retain.length > 0) {
								for (NSInteger d = 0; d < blockIndex; d++) {
									Line *preBreak = [Line withString:[tmpElements[d] string] type:[(Line*)tmpElements[d] type]  pageSplit:YES];
									[currentPage addObject:preBreak];
								}
								
								// Add on the previous page
								Line *preDialogue = [Line withString:retain type:spillerElement.type pageSplit:YES];
								Line *preMore = [Line withString:@"(MORE)" type:more pageSplit:YES];
								
								// These are the same, to inform live pagination where we are in the document
								preDialogue.position = spillerElement.position;
								preMore.position = spillerElement.position;
								// Also inherit change status
								preDialogue.changed = spillerElement.changed;
								
								[currentPage addObject:preDialogue];
								[currentPage addObject:preMore];
								[self.pages addObject:currentPage];

								// Add page break
								[self pageBreak:spillerElement position:breakPosition];
								spillerElement.unsafeForPageBreak = YES;
								
								currentPage = [NSMutableArray array];

								// Set correct dialogue type
								LineType contdType;
								LineType dialogueType;
								if (spillerElement.isDualDialogue) {
									dialogueType = dualDialogue;
									contdType = dualDialogueCharacter;
								}
								else {
									dialogueType = dialogue;
									contdType = character;
								}
								
								// Add the remaining stuff on the next page and inherit dual dialogue stuff
								Line *postCue = [Line withString:[element.string stringByAppendingString:@" (CONT'D)"] type:contdType pageSplit:YES];
								if (element.nextElementIsDualDialogue) postCue.nextElementIsDualDialogue = YES;
								Line *postDialogue = [Line withString:split type:dialogueType pageSplit:YES];
								
								// Inherit changes
								postCue.changed = spillerElement.changed;
								postDialogue.changed = spillerElement.changed;
								
								// Position indexes for live pagination
								postCue.position = preDialogue.position + preDialogue.string.length;
								postDialogue.position = postCue.position;
								
								[currentPage addObject:postCue];
								[currentPage addObject:postDialogue];
								
								currentY = 0;
								currentY += [self elementHeight:postCue lineHeight:lineHeight];
								currentY += [self elementHeight:postDialogue lineHeight:lineHeight];

								// Add possible remaining dialogue elements
								if (blockIndex + 1 > tmpElements.count) continue;
								NSInteger position = postDialogue.position + postDialogue.string.length;
								for (NSInteger d = blockIndex + 1; d < tmpElements.count; d++) {
									Line *postElement = tmpElements[d];
									
									Line *postBreak = [[Line alloc] initWithString:postElement.string type:postElement.type pageSplit:YES];
									postBreak.changed = postElement.changed;
									postBreak.position = position; // String index from file
									position += postBreak.string.length;
									currentY += [self elementHeight:postBreak lineHeight:lineHeight];
									
									[currentPage addObject:postBreak];
								}

								// Don't let this loop handle the buffer
								continue;
							} else {
								// Nothing to retain, move whole block on next page
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								[self pageBreak:element position:0];
							}

						} else {
							// Parenthetical spills, but it's not the SECOND element rather than somewhere else in the block
							if ((spillerElement.type == parenthetical || spillerElement.type == dualDialogueParenthetical) && blockIndex > 1) {
								// Add the preceeding elements
								for (NSInteger d = 0; d < blockIndex; d++) {
									Line *dElement = tmpElements[d];
									[currentPage addObject:dElement];
								}
								
								LineType charType;
								LineType dialogueType;
								if (spillerElement.isDualDialogue) {
									dialogueType = dualDialogue;
									charType = dualDialogueCharacter;
								}
								else {
									dialogueType = dialogue;
									charType = character;
								}
								
								// Add (more) after the dialogue
								[currentPage addObject:[Line withString:@"(MORE)" type:more pageSplit:YES]];
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								
								Line* postCue = [[Line alloc] initWithString:[element.string stringByAppendingString:@" (CONT'D)"] type:charType pageSplit:YES];
								[currentPage addObject:postCue];
								[currentPage addObject:spillerElement];
								
								// Count heights
								currentY = 0;
								currentY += [self elementHeight:postCue lineHeight:lineHeight];
								currentY += [self elementHeight:spillerElement lineHeight:lineHeight];
								
								// Add the rest of the stuff
								for (NSInteger d = blockIndex + 1; d < tmpElements.count; d++) {
									Line *dElement = tmpElements[d];
									currentY += [self elementHeight:dElement lineHeight:lineHeight];
									[currentPage addObject:dElement];
								}
								
								// Add page break for live pagination
								[self pageBreak:spillerElement position:0];
								
								// Don't let the loop take care of the buffered elements
								continue;
							}
						}
						
					// Otherwise push the dialogue on the next page
					} else {
						// Normal split dialogue
						if (!spillerElement.isDualDialogue) {
							
							[_pages addObject:currentPage];
							currentPage = [NSMutableArray array];
						
							[self pageBreak:spillerElement position:0];
						
						// Spiller is dual dialogue, which means we need to move all of the previous dialogue
						// on the next page too. This makes me ache.
						} else {
							
							NSMutableArray *elementsToMove = [NSMutableArray array];
							Line *preceedingDialogue = currentPage.lastObject;
							
							while (preceedingDialogue.isDialogue) {
								[elementsToMove insertObject:preceedingDialogue atIndex:0];
								[currentPage removeLastObject];
								
								// Break at character
								if (preceedingDialogue.type == character) break;
								
								preceedingDialogue = currentPage.lastObject;
							}
							
							[_pages addObject:currentPage];
							currentPage = [NSMutableArray array];
							
							// do a switcharoo, put tmp elements at the end of elements to move and vice-versa
							[elementsToMove addObjectsFromArray:tmpElements];
							tmpElements = elementsToMove;
						}
					}
				}
				else if (element.type == action) {
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:-1];

				} else {
					// Whatever, let's just push this element on the next page
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:0];
				}
				
				currentY = 0;
			}
			
			NSInteger previousDialogueHeight = 0;
			NSInteger dualDialogueHeight = 0;
			
			// Add remaining elements
			for (Line *el in tmpElements) {
				NSInteger h = [self elementHeight:el lineHeight:lineHeight];
				
				// Catch dual dialogue
				if (el.type == character || el.isDialogueElement) {
					if (el.type == character) previousDialogueHeight = 0;
					// Save dialogue block height for later use
					previousDialogueHeight += h;
					
					// Append y position
					currentY += h;
					if ([currentPage count] > 0) { currentY += [FountainPaginator spaceBeforeForLine:el]; }
				}
				else if (el.type == dualDialogueCharacter || el.isDualDialogueElement) {
					if (el.type == dualDialogueCharacter) dualDialogueHeight = 0;
					
					// Add to this block height
					dualDialogueHeight += h;
					
					// If this block is higher, add the height difference only
					if (dualDialogueHeight > previousDialogueHeight) {
						currentY += dualDialogueHeight - previousDialogueHeight;
					}
				} else {
					// Update y position
					currentY += h;
					if ([currentPage count] > 0) { currentY += [FountainPaginator spaceBeforeForLine:el]; }
				}
				
				[currentPage addObject:el];
			}
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
	if (i < self.script.count) return YES; else return NO;
}

+ (CGFloat)lineHeight {
	return LINE_HEIGHT;
}
+ (CGFloat)spaceBeforeForElement:(Line *)element
{
	CGFloat spaceBefore = 0;
	
	NSString *type  = element.typeAsFountainString;
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

- (CGFloat)elementHeight:(Line *)element lineHeight:(CGFloat)lineHeight {
	NSString *string = element.stripFormattingCharacters;
	return [FountainPaginator heightForString:string font:_font maxWidth:[self widthForElement:element] lineHeight:lineHeight];
}

- (NSInteger)widthForElement:(Line *)element
{
	// This uses Fountain element keywords to make no difference between dual and normal dialogue etc.
	
	NSInteger width = 0;
	NSString *type  = element.typeAsFountainString;
	
	if ([type isEqualToString:@"Action"] || [type isEqualToString:@"General"] || [type isEqualToString:@"Transition"]) {
		width   = 425;
		if (!_A4) width = 440;
	}
	if (element.type == heading) {
		width = 425 - 32; // Make space for the scene number
		if (!_A4) width = 440 - 32;
	}
	else if ([type isEqualToString:@"Character"]) {
		width   = 144;
	}
	else if ([type isEqualToString:@"Dialogue"]) {
		width   = 248; // 217
	}
	else if ([type isEqualToString:@"Parenthetical"]) {
		width   = 200;
	}
	
	return width;
}

/*
 To get the height of a string we need to create a text layout box, and use that to calculate the number
 of lines of text we have, then multiply that by the line height. This is NOT the method Apple describes
 in their docs, but we have to do this because getting the size of the layout box (Apple's recommended
 method) doesn't take into account line height, so text won't display correctly when we try and print.
 */
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight
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
	
	//NSLog(@"-> number of lines: %lu", numberOfLines);
	
	return numberOfLines * lineHeight;
}
- (void)pageBreak:(Line*)line position:(CGFloat)position {
	if (!_livePagination) return; // Don't run this for non-live pagination

	NSNumber *value = [NSNumber numberWithFloat:position];

	if (value && line) {
		[_pageBreaks addObject:@{ @"line": line, @"position": value }];
	}
}

- (NSInteger)pageNumberFor:(NSInteger)location {
	NSInteger pageNumber = 1;
	for (NSArray *page in _pages) {
		Line *firstElement = [page firstObject];
		Line *lastElement = [page lastObject];
		if (location >= firstElement.position && location <= lastElement.position + lastElement.string.length) {
			return pageNumber;
		}
		pageNumber++;
	}
	return 0;
}

#pragma mark - Beat helper methods

+ (CGFloat)spaceBeforeForLine:(Line*)line {
	if (line.isSplitParagraph) return 0;
	else if (line.type == heading) return LINE_HEIGHT * 2;
	else if (line.type == character || line.type == dualDialogueCharacter) return LINE_HEIGHT;
	else if (line.type == dialogue) return 0;
	else if (line.type == parenthetical) return 0;
	else if (line.type == dualDialogue) return 0;
	else if (line.type == dualDialogueParenthetical) return 0;
	else if (line.type == transitionLine) return LINE_HEIGHT;
	else if (line.type == action) return LINE_HEIGHT;
	else return LINE_HEIGHT;
}

- (void)cancel {
	self.pages = nil;
}

- (NSArray*)dialogueBlockFor:(Line*)element {
	NSInteger i = [self.script indexOfObject:element];
	NSInteger startIndex = i;
	NSMutableArray *block = [NSMutableArray array];
	
	bool isDualDialogue = NO;
	
	while (i < self.script.count) {
		Line *line = self.script[i];
		
		// Break under certain conditions
		if (line.type == character && i > startIndex) break;
		else if (!line.isDialogue && !line.isDualDialogue) break;
		else if (line.isDualDialogue) isDualDialogue = YES;
		else if (isDualDialogue && (line.isDialogue || line.type == dualDialogueCharacter)) break; // probably Reached next dialogue block
		
		[block addObject:line];
		
		i++;
	}
	
	return block;
}

- (NSInteger)heightForDialogueBlock:(NSArray*)block {
	// calculate the height for entire dialogue block, including possible dual dialogue
	NSInteger dialogueBlockHeight = 0;
	NSInteger previousDialogueBlockHeight = 0;
	
	bool isDualDialogue = NO;
	
	for (Line* line in block) {
		// Break under certain conditions
		if (!line.isDialogue && !line.isDualDialogue) break;
		if (line.isDualDialogue) isDualDialogue = YES;
		if (isDualDialogue && line.isDialogue) break;
		
		if (line.type == dualDialogueCharacter) {
			previousDialogueBlockHeight = dialogueBlockHeight;
			dialogueBlockHeight = 0;
		}
		
		dialogueBlockHeight += [self elementHeight:line lineHeight:LINE_HEIGHT];
	}
	
	// Set the height to be the longer one
	if (previousDialogueBlockHeight > dialogueBlockHeight) dialogueBlockHeight = previousDialogueBlockHeight;
	
	return dialogueBlockHeight;
}

- (NSArray*)separateDualDialogue:(NSArray*)dialogueBlock {
	NSMutableArray *left = [NSMutableArray array];
	NSMutableArray *right = [NSMutableArray array];
	
	for (Line* line in dialogueBlock) {
		if (line.isDialogue) [left addObject:line];
		if (line.isDualDialogue) [right addObject:line];
	}
	
	return @[left, right];
}

- (Line*)findDialogueSpiller:(NSArray*)dialogueBlock remainingSpace:(NSInteger)remainingSpace {
	Line* spillerElement;
	NSInteger dialogueHeight = 0;
	
	for (Line *line in dialogueBlock) {
		NSInteger h = [self elementHeight:line lineHeight:LINE_HEIGHT];
		if (dialogueHeight + h > remainingSpace) { spillerElement = line; break; }
		else { dialogueHeight += h; }
	}
	
	return spillerElement;
}

- (NSDictionary*)splitDialogue:(NSArray*)dialogueBlock spiller:(Line*)spillerElement remainingSpace:(NSInteger)remainingSpace height:(NSInteger)dialogueHeight {
	
	// NOTE: Remember to calculate Y after this operation
	
	Line *pageBreakItem;
	NSInteger suggestedPageBreak = -1;
	NSInteger blockIndex = [dialogueBlock indexOfObject:spillerElement];
	
	NSMutableArray *retainedElements = [NSMutableArray array];
	NSMutableArray *nextPageElements = [NSMutableArray array];
	
	if (spillerElement.type == dialogue || spillerElement.type == dualDialogue) {
		// Break into sentences
		NSString *stripped = spillerElement.stripFormattingCharacters;
		NSMutableArray *sentences = [NSMutableArray arrayWithArray:[stripped matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
		if (!sentences.count && stripped.length) [sentences addObject:stripped];
		
		NSString *text = @"";
		NSString *retain = @"";
		NSString *split = @"";
		CGFloat breakPosition = 0;
		
		int sIndex = 0;
		for (NSString *rawSentence in sentences) {
			NSString *sentence = [rawSentence stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			if (sIndex == 0) text = [text stringByAppendingFormat:@"%@", sentence];
			else text = [text stringByAppendingFormat:@" %@", sentence];
			
			Line *tempElement = [[Line alloc] initWithString:text type:dialogue];
			
			NSInteger h = [self elementHeight:tempElement lineHeight:LINE_HEIGHT];
			
			if (h < remainingSpace) {
				breakPosition = h;
				if (sIndex == 0) retain = [retain stringByAppendingFormat:@"%@", sentence];
				else retain = [retain stringByAppendingFormat:@" %@", sentence];
			} else {
				split = [split stringByAppendingFormat:@" %@", sentence];
			}
			
			sIndex++;
		}
		
		NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
		retain = splitElements[0];
		split = splitElements[1];
		
		// Trim split text
		retain = [retain stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		split = [split stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	
		// If we have something to retain, do it, otherwise just break to next page
		if (retain.length > 0) {
			for (NSInteger d = 0; d < blockIndex; d++) {
				Line *preBreak = [Line withString:[dialogueBlock[d] string] type:[(Line*)dialogueBlock[d] type]  pageSplit:YES];
				[retainedElements addObject:preBreak];
			}
			
			// Add on the previous page
			Line *preDialogue = [Line withString:retain type:spillerElement.type pageSplit:YES];
			Line *preMore;
			if (split.length > 0) preMore = [Line withString:@"(MORE)" type:more pageSplit:YES];
			
			// These are the same, to inform live pagination where we are in the document
			preDialogue.position = spillerElement.position;
			preDialogue.changed = spillerElement.changed; // inherit change status
			if (split.length) preMore.position = spillerElement.position;
						
			[retainedElements addObject:preDialogue];
			if (preMore != nil) [retainedElements addObject:preMore];

			spillerElement.unsafeForPageBreak = YES;
			suggestedPageBreak = breakPosition;
			pageBreakItem = spillerElement;

			// Set correct dialogue type
			LineType contdType;
			LineType dialogueType;
			if (spillerElement.isDualDialogue) {
				dialogueType = dualDialogue;
				contdType = dualDialogueCharacter;
			}
			else {
				dialogueType = dialogue;
				contdType = character;
			}
			
			if (split.length) {
				// Add the remaining stuff on the next page and inherit dual dialogue stuff
				Line *element = dialogueBlock.firstObject;
				Line *postCue = [Line withString:[element.string stringByAppendingString:@" (CONT'D)"] type:contdType pageSplit:YES];
				if (element.nextElementIsDualDialogue) postCue.nextElementIsDualDialogue = YES;
				Line *postDialogue = [Line withString:split type:dialogueType pageSplit:YES];
				
				// Inherit changes
				postCue.changed = spillerElement.changed;
				postDialogue.changed = spillerElement.changed;
				
				// Position indexes for live pagination
				postCue.position = preDialogue.position + preDialogue.string.length;
				postDialogue.position = postCue.position;
				
				[nextPageElements addObject:postCue];
				[nextPageElements addObject:postDialogue];
						
				// Add possible remaining dialogue elements
				NSInteger position = postDialogue.position + postDialogue.string.length;
				for (NSInteger d = blockIndex + 1; d < dialogueBlock.count; d++) {
					Line *postElement = dialogueBlock[d];
					
					Line *postBreak = [[Line alloc] initWithString:postElement.string type:postElement.type pageSplit:YES];
					postBreak.changed = postElement.changed;
					postBreak.position = position; // String index from file
					position += postBreak.string.length;
					
					[nextPageElements addObject:postBreak];
				}
			}
		} else {
			// Nothing to retain, move whole block on next page
			[nextPageElements addObjectsFromArray:dialogueBlock];
			suggestedPageBreak = 0;
			pageBreakItem = dialogueBlock.firstObject;
		}
		
		return @{
			@"page break item": pageBreakItem,
			@"position": @(suggestedPageBreak),
			@"retained": retainedElements,
			@"next page": nextPageElements
		};
	}
	
	return nil;
}

@end

/*

on niin yksinkertaista
uskotella olevansa päivä joka ei milloinkaan laske
olla kaukaisten hailakkain vuorten takaa nouseva säteinen paiste
on niin vaikeaa
myöntää olevansa vain satunnainen kuiskaus
olla päivänkajo joka aina likempänä kuin aamua
  on hiipuvaa iltaa

*/
