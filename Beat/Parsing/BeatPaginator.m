//
//  FountainPaginator.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
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

#import "BeatPaginator.h"
#import "Line.h"
#import "RegExCategories.h"

#define LINE_HEIGHT 12.5

@interface BeatPaginator ()

@property (weak, nonatomic) NSDocument *document;
@property (strong, nonatomic) NSArray *script;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSString *textCache;
@property bool paginating;
@property bool A4;
@property (nonatomic) NSPrintInfo *printInfo;
@property BeatFont *font;

@property NSMutableIndexSet *changedIndices;

// WIP
@property (nonatomic) bool livePagination;

@end

@implementation BeatPaginator

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

- (id)initWithScript:(NSArray *)elements printInfo:(NSPrintInfo*)printInfo
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_printInfo = printInfo;
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
	if (self.pages.count == 0 || (index > self.pages.count - 1)) {
		return @[];
	}
	
	return self.pages[index];
}

- (NSUInteger)numberOfPages
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if (self.pages.count == 0) [self paginate];
	return self.pages.count;
}
- (NSArray*)lengthInEights {
	if (self.pages.count == 0) [self paginate];
	
	NSInteger pageCount = self.pages.count - 1;
	NSInteger eights = (NSInteger)round(_lastPageHeight / (1.0/8.0));
	
	// If the last page is almost full, just calculate it as one full page
	if (eights == 8) {
		pageCount++;
		eights = 0;
	}
	
	if (pageCount < 0) return nil;
	else return @[@(pageCount), @(eights)];
}

/*

 You, who shall resurface following the flood
 In which we have perished,
 Contemplate —
 When you speak of our weaknesses,
 Also the dark time
 That you have escaped.
 
*/

- (void)setPageSize:(BeatPaperSize)pageSize {
	_printInfo = [BeatPaperSizing printInfoFor:pageSize];
}

- (void)setScript:(NSArray *)script {
	NSMutableArray *lines = [NSMutableArray array];
	for (Line *line in script) {
		if (line.omitted || line.type == empty) continue;
		[lines addObject:line];
	}
	_script = lines;
}

- (void)paginateLines:(NSArray*)lines {
	self.script = lines;
	self.pages = [NSMutableArray array];
	self.pageBreaks = [NSMutableArray array];
	[self paginate];
}
- (void)paginate {
	[self paginateFromIndex:0 startFromLine:nil page:nil];
}
- (void)paginateFromIndex:(NSInteger)fromIndex startFromLine:(Line*)firstLine page:(NSMutableArray*)firstPage
{
	bool test = NO;
	
	if (!self.script.count) return;
	
	// Get paper size from the document
	if (_document || _printInfo) {
		NSPrintInfo *printInfo;
		if (_document) printInfo = _document.printInfo.copy;
		else printInfo = _printInfo.copy;
	
		printInfo = [BeatPaperSizing setMargins:printInfo];
		
		// Check paper size
		if (printInfo.paperSize.width > 595) _A4 = NO;
		_A4 = YES;
		
		CGFloat w = roundf(printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin);
		CGFloat h = roundf(printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin);
		
		_paperSize = CGSizeMake(w, h);
	} else {
		_paperSize = CGSizeMake(595, 821);
	}
		
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
			currentY += [BeatPaginator spaceBeforeForLine:line];
			currentY += [self elementHeight:line lineHeight:LINE_HEIGHT];
			[currentPage addObject:line];
		}
	}
	
	@autoreleasepool {
		CGFloat spaceBefore;
				
		// create a tmp array that will hold elements to be added to the pages
		NSMutableArray *tmpElements = [NSMutableArray array];
		
		// walk through the elements array
		for (NSInteger i = 0; i < self.script.count; i++) {
			if (!_paginating && _livePagination) {
				// An experiment in canceling background-thread pagination
				[self cancel];
				return;
			}
			
			Line *element  = (self.script)[i];
			if ([element.string isEqualToString:@"INT. STJERNSBERG/MATSALEN -- KVÄLL[[COLOR GREEN]]"]) test = YES;
			
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
			if (_pageBreaks.count == 0 && _livePagination) [self pageBreak:element position:0 type:@"First page"];
			
			// Reset Y if the page is empty
			if (currentPage.count == 0) currentY = initialY;
			
			// catch page breaks immediately
			if (element.type == pageBreak) {
				// close the open page
				[currentPage addObject:element];
				[self.pages addObject:currentPage];

				[self pageBreak:element position:-1 type:@"Forced page break"];
				
				// reset currentPage and the currentY value
				currentPage = [NSMutableArray array];
				currentY    = initialY;
				
				continue;
			}
			
			
			#pragma mark Calculate block height
			
			// Save space before for this line
			spaceBefore = [BeatPaginator spaceBeforeForLine:element];
			
			// Catch wrong parsing.
			// We SHOULD NOT have orphaned dialogue. This can happen with non-forced text.
			if (element.type == dialogue && element.string.length == 0) continue;
			 
			// We could get the whole block height like this:
			NSArray *blck = [self blockFor:element];
			
			// Calculate block height
			NSInteger fullHeight = [self heightForBlock:blck page:currentPage];
			if (fullHeight <= 0) continue; // Ignore this block if it's empty
			
			// Fix to get styling to show up in PDFs. I have no idea.
			if (![element.string isMatch:RX(@" $")]) {
				element.string = [NSString stringWithFormat:@"%@%@", element.string, @""];
			}
			
			// Add whole block into temporary elements
			[tmpElements addObjectsFromArray:blck];
			
			#pragma mark Break elements onto pages
			
			// BREAKING ELEMENTS ONTO PAGES
			// Figure out which element went overboard
			if (currentY + fullHeight > maxPageHeight) {
				CGFloat overflow = maxPageHeight - (currentY + fullHeight);
				
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
					[self pageBreak:(Line*)tmpElements.lastObject position:-1 type:@"Generally squeezed"];
					
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
					
					// If it's a scene heading, spiller element is the line after heading line
					if (element.type == heading) {
						headingBlock = YES;
						
						if (blck.count > 1) spillerElement = blck.lastObject;
						else spillerElement = element;
						
						// Push to next page if it would be only 1 line or something
						if (fullHeight - fabs(overflow) < lineHeight * 3
							&& fabs(overflow) > lineHeight * 2) {
							handled = YES;
						}
					} else {
						spillerElement = element;
					}
										
					// Split first paragraph scene into two if it's higher than one line
					NSInteger limit = lineHeight;
					NSInteger space = maxPageHeight - currentY;
					
					if (fabs(overflow) > limit && space > limit * 2 && !handled) {
						NSMutableArray *words = [spillerElement.stripFormatting componentsSeparatedByString:@" "].mutableCopy;
						
						NSInteger space = maxPageHeight - currentY;
						
						// We substract heading line height from the remaining space
						if (headingBlock) space -= [self heightForBlock:@[element] page:currentPage];
						
						NSString *text = @"";
						NSString *retain = @"";
						NSString *split = @"";
						
						CGFloat breakPosition = 0;
						
						// Loop through words and count the height
						for (NSInteger wordIndex = 0; wordIndex < words.count; wordIndex++) {
							NSString *word = words[wordIndex];
							
							if ([word containsString:@"\n"] && word.length > 1) {
								// Move line break at end of the word and add a new word into array
								NSArray *linebreak = [word componentsSeparatedByString:@"\n"];
								word = [NSString stringWithFormat:@"%@\n", linebreak[0]];
								[words insertObject:linebreak[1] atIndex:wordIndex+1];
							}
							
							if (wordIndex == 0) text = [text stringByAppendingFormat:@"%@", word];
							else {
								// This is a very quick and dirty fix for weird edge cases
								if (word.length) {
									if ([word characterAtIndex:word.length-1] == '\n') text = [text stringByAppendingFormat:@"%@", word];
									else text = [text stringByAppendingFormat:@" %@", word];
								}
								else text = [text stringByAppendingFormat:@" %@", word];
							}
							
							Line *tempElement = [[Line alloc] initWithString:text type:action];
							
							NSInteger h = [self elementHeight:tempElement lineHeight:lineHeight];
							if (h < space) {
								breakPosition = h;
								if (wordIndex == 0) retain = [retain stringByAppendingFormat:@"%@", word];
								else if (word.length) {
									if ([word characterAtIndex:word.length-1] == '\n') retain = [retain stringByAppendingFormat:@"%@", word];
									else retain = [retain stringByAppendingFormat:@" %@", word];
								}
								else retain = [retain stringByAppendingFormat:@" %@", word];
							} else {
								split = [split stringByAppendingFormat:@" %@", word];
							}
						}
						
						NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
						Line *prePageBreak = splitElements[0];
						Line *postPageBreak = splitElements[1];

						// If it's a heading we need special rules
						if (headingBlock) {
							// We had something remain on the original page
							if (retain.length) {
								[currentPage addObject:element];
								[currentPage addObject:prePageBreak];
								[_pages addObject:currentPage];
								
								// Add page break for live pagination
								[self pageBreak:spillerElement position:breakPosition type:@"Heading block"];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:postPageBreak];
								currentY = [self elementHeight:postPageBreak lineHeight:lineHeight];
							}
							// Nothing remained, move whole scene heading to next page
							else {
								[_pages addObject:currentPage];
								
								// Page break for live pagination
								[self pageBreak:element position:0 type:@"Heading block moved on next page"];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:element];
								[currentPage addObject:postPageBreak];
								currentY = fullHeight - spaceBefore; // Remove space from beginning, because this is the first element
							}
						} else {
							[currentPage addObject:prePageBreak];
							[_pages addObject:currentPage];
							
							// Add page break info (for live pagination if in use)
							[self pageBreak:spillerElement position:breakPosition type:@"Action or heading"];
							
							currentPage = [NSMutableArray array];
							[currentPage addObject:postPageBreak];
							currentY = [self elementHeight:postPageBreak lineHeight:lineHeight];
						}
												
						continue;
						
					} else {
						// Close page and reset
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];

						// Add page break info (for live pagination if in use)
						[self pageBreak:element position:0 type:@"Whatever"];
					}
				}
				
				#pragma mark Split dialogue
				// This is a convoluted system because of the way Fountain handles dual dialogue.
				// Try to keep up.
				
				else if (element.type == character || element.type == dualDialogueCharacter) {
					NSInteger remainingSpace = maxPageHeight - currentY;
				
					NSMutableArray *retainedLines = [NSMutableArray array];
					NSMutableArray *nextPageLines = [NSMutableArray array];
					
					Line *pageBreakElement;
					NSInteger pageBreakPosition = 0;
					
					NSArray *dialogueBlock = [self dialogueBlockFor:element];
					NSInteger dialogueH = [self heightForDialogueBlock:dialogueBlock page:currentPage];
					
					// Squeeze the block on page
					if (labs(remainingSpace - dialogueH) <= LINE_HEIGHT) {
						[currentPage addObjectsFromArray:dialogueBlock];
						[_pages addObject:currentPage];
						
						currentPage = [NSMutableArray array];
						currentY = 0;
						
						// Add page break info (for live pagination if in use)
						[self pageBreak:dialogueBlock.lastObject position:-1 type:@"Squeezed dialogue"];
						continue; // Don't let the loop take care of the tmp buffer here
					}
					
					// Normal, single dialogue
					if (!element.nextElementIsDualDialogue) {
						Line *spillEl = [self findDialogueSpiller:dialogueBlock remainingSpace:remainingSpace];
									
						NSDictionary *split = [self splitDialogue:dialogueBlock spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:dialogueBlock page:currentPage]];
						
						if ([(NSArray*)split[@"retained"] count]) {
							[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
							
							pageBreakElement = (Line*)split[@"page break item"];
							pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
							
							[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
						} else {
							pageBreakElement = dialogueBlock.lastObject;
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
							split = [self splitDialogue:dual[1] spiller:spillEl2 remainingSpace:remainingSpace height:[self heightForDialogueBlock:dual[1] page:currentPage]];
							
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
							
							split = [self splitDialogue:dual[0] spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:dual[0] page:currentPage]];
							
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
							
							NSDictionary *splitLeft = [self splitDialogue:leftDialogue spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:leftDialogue page:currentPage]];
							NSDictionary *splitRight = [self splitDialogue:rightDialogue spiller:spillEl2 remainingSpace:remainingSpace height:[self heightForDialogueBlock:rightDialogue page:currentPage]];
							
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
						
						// For some reason, this information is lost like tears in the rain, so we'll reset it, just in case
						if (element.nextElementIsDualDialogue) {
							Line* firstLine = (Line*)retainedLines.firstObject;
							firstLine.nextElementIsDualDialogue = YES;
						}
					}
					
					// Add objects on current page
					[currentPage addObjectsFromArray:retainedLines];
					[_pages addObject:currentPage];
					
					// Add page break for live pagination
					[self pageBreak:pageBreakElement position:pageBreakPosition type:@"Dialogue"];
					
					currentPage = [NSMutableArray array];
					[currentPage addObjectsFromArray:nextPageLines];
					currentY = [self heightForDialogueBlock:nextPageLines page:currentPage];
										
					// Ignore the rest of the block
					[tmpElements setArray:dialogueBlock];
					
					continue;
				}
				else if (element.type == action) {
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:-1 type:@"Some action"];

				} else {
					// Whatever, let's just push this element on the next page
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:0 type:@"Whatever, again"];
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
					if ([currentPage count] > 0) { currentY += [BeatPaginator spaceBeforeForLine:el]; }
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
					if (currentPage.count > 0) currentY += [BeatPaginator spaceBeforeForLine:el];
				}
				
				[currentPage addObject:el];
			}
		}
		
		[_pages addObject:currentPage];
	}
	
	// Remove last page if it's empty
	NSArray *lastPage = _pages.lastObject;
	
	if (lastPage.count == 0) [_pages removeLastObject];
		
	_lastPageHeight = (float)currentY / (float)maxPageHeight;
	if (_lastPageHeight == 0) _lastPageHeight = -1.0;
	
	// If there's only one page and the last page height is 0, make the last page height full
	// if (_pages.count == 1 && _pages[0].count && currentY == 0) _lastPageHeight = 1.0;
	// Else just return the normal calculation
	// else _lastPageHeight = (float)currentY / (float)maxPageHeight;
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
	NSString *string = element.stripFormatting;
	return [BeatPaginator heightForString:string font:_font maxWidth:[self widthForElement:element] lineHeight:lineHeight];
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
#if TARGET_OS_IOS
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
		
	return numberOfLines * lineHeight;
}
- (void)pageBreak:(Line*)line position:(CGFloat)position type:(NSString*)reason {
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

- (NSArray*)blockFor:(Line*)line {
	NSMutableArray *block = [NSMutableArray array];
	
	NSInteger i = [self.script indexOfObject:line];
	if (i == self.script.count - 1) return @[line];

	LineType type = line.type;
	if (type != heading && type != character && type != dualDialogueCharacter) return @[line];
	
	NSInteger l = i + 1;
	[block addObject:line];
	
	while (l < self.script.count) {
		Line *el = self.script[l];

		if (el.type == empty || el.string.length == 0) {
			l++;
			continue;
		}
		
		if (line.type == heading) {
			if (el.type == action) {
				[block addObject:el];
				break;
			}
			else break;
		}

		else if (line.type == character) {
			if (el.isDialogueElement) [block addObject:el];
			else break;
		}
		
		else if (line.type == dualDialogueCharacter) {
			if (el.isDualDialogueElement) [block addObject:el];
			else break;
		}
				
		l++;
	}
	
	if (line.nextElementIsDualDialogue) {
		// Find the dual dialogue element
		NSInteger d = i + 1;
		
		Line *ddLine;
		while (d < self.script.count) {
			Line *el = self.script[d];
			if (el.type == dualDialogueCharacter) {
				ddLine = el;
				break;
			}
			
			d++;
		}
		
		if (ddLine) [block addObjectsFromArray:[self blockFor:ddLine]];
	}
		
	return block;
}

- (NSInteger)heightForBlock:(NSArray*)block {
	return [self heightForBlock:block page:nil];
}

- (NSInteger)heightForBlock:(NSArray*)block page:(NSArray*)currentPage {
	if ([(Line*)block.firstObject type] == character) return [self heightForDialogueBlock:block page:currentPage];
	
	NSInteger fullHeight = 0;
	
	for (Line *line in block) {
		CGFloat spaceBefore = 0;
		if (currentPage.count || line != block.firstObject) spaceBefore = [BeatPaginator spaceBeforeForLine:line];
		
		CGFloat elementWidth = [self widthForElement:line];
		NSInteger height = [BeatPaginator heightForString:line.stripFormatting font:_font maxWidth:elementWidth lineHeight:LINE_HEIGHT];
		
		fullHeight += spaceBefore + height;
	}
	

	return fullHeight;
}

- (NSInteger)heightForDialogueBlock:(NSArray*)block page:(NSArray*)currentPage {
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
	
	if (currentPage.count > 0) dialogueBlockHeight += [BeatPaginator spaceBeforeForLine:block.firstObject];
	
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
	// NOTE #2: ABANDON ALL HOPE
	
	Line *pageBreakItem;
	NSInteger suggestedPageBreak = -1;
	NSInteger blockIndex = [dialogueBlock indexOfObject:spillerElement];
	
	NSMutableArray *retainedElements = [NSMutableArray array];
	NSMutableArray *nextPageElements = [NSMutableArray array];
	
	// If we got stuck in first parenthetical, throw the whole block on the next page
	if (((spillerElement.type == parenthetical || spillerElement.type == dualDialogueParenthetical) && blockIndex < 2) || spillerElement.type == character) {
		// ALERT: CHECK THIS

		[nextPageElements addObjectsFromArray:dialogueBlock];
		suggestedPageBreak = 0;
		pageBreakItem = dialogueBlock.firstObject;
	}
	
	else if (spillerElement.type == dialogue || spillerElement.type == dualDialogue) {
		// Break into sentences
		NSString *stripped = spillerElement.stripFormatting;
		
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
		Line *preDialogue = splitElements[0];
		Line *postDialogue = splitElements[1];
	
		// If we have something to retain, do it, otherwise just break to next page
		if (retain.length > 0) {
			for (NSInteger d = 0; d < blockIndex; d++) {
				Line *preBreak = [Line withString:[dialogueBlock[d] string] type:[(Line*)dialogueBlock[d] type]  pageSplit:YES];
				[retainedElements addObject:preBreak];
			}
			
			// Add on the previous page
			Line *preMore;
			
			LineType moreType = (spillerElement.isDialogue) ? more : dualDialogueMore;
			if (postDialogue.length > 0) {
				preMore = [Line withString:@"(MORE)" type:moreType pageSplit:YES];
				preMore.position = spillerElement.position;
			}
						
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
			
			if (postDialogue.length) {
				// Add the remaining stuff on the next page and inherit dual dialogue boolean
				Line *element = dialogueBlock.firstObject;
				Line *postCue = [Line withString:[element.stripFormatting stringByAppendingString:@" (CONT'D)"] type:contdType pageSplit:YES];
				
				if (element.nextElementIsDualDialogue) postCue.nextElementIsDualDialogue = YES;
				postDialogue.type = dialogueType;
								
				// Position indexes for live pagination
				postCue.position = preDialogue.position + preDialogue.string.length;
				
				[nextPageElements addObject:postCue];
				[nextPageElements addObject:postDialogue];
				
				// Add possible remaining dialogue elements
				// IDK why this is different than the method below
				NSInteger position = postDialogue.position + postDialogue.string.length;
				for (NSInteger d = blockIndex + 1; d < dialogueBlock.count; d++) {
					Line *postElement = dialogueBlock[d];
					
					Line *postBreak = [[Line alloc] initWithString:postElement.string type:postElement.type pageSplit:YES];
					postBreak.changed = postElement.changed;
					postBreak.position = position; // String index from file
					position += postBreak.string.length;
					
					[nextPageElements addObject:postBreak];
				}
			} else {
				// There is something else left to process in the dialogue block, even if we didn't split anything
				// IDK why this is different than the method above ^
				if (spillerElement != dialogueBlock.lastObject) {
					NSInteger splitIdx = [dialogueBlock indexOfObject:spillerElement];
					if (splitIdx < dialogueBlock.count - 1) {
						NSArray *splitItems = [dialogueBlock subarrayWithRange:(NSRange){ splitIdx + 1, dialogueBlock.count - (splitIdx+1) }];
						[nextPageElements addObjectsFromArray:splitItems];
					}
				}
			}
		} else {
			// Nothing to retain, move whole block on next page
			[nextPageElements addObjectsFromArray:dialogueBlock];
			suggestedPageBreak = 0;
			pageBreakItem = dialogueBlock.firstObject;
		}
		
		NSDictionary *result =  @{
			@"page break item": pageBreakItem,
			@"position": @(suggestedPageBreak),
			@"retained": retainedElements,
			@"next page": nextPageElements
		};
				
		return result;
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
