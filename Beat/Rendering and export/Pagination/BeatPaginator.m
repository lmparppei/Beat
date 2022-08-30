//
//  FountainPaginator.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 WORK IN PROGRESS.

 This is very, very loosely based on the original FNPaginator code, rewritten
 to use the Line class driving ContinuousFountainParser.
  
 Original Fountain repository pagination code was totally convoluted and had
 many obvious bugs and stuff that really didn't work in many places.
 I went out of my way to make my own pagination engine, just to end up with
 something almost as convoluted.
 
 Maybe it was an important journey - I learned how this actually works and
 got to spend a nice day coding in my bathrobe. I had two feature scripts that
 required my attention, but yeah. This is duct-taped together to give somewhat
 acceptable pagination results.
 
 It doesn't matter - I have the chance to spend my days doing something I'm
 intrigued by, and probably it makes it less likely that I'll get dementia or
 other memory-related illness later in life. I don't know.
 
 I have found the fixed values with goold old trial & error. As we are using a
 WKWebView to render the HTML file, the pixel coordinates do not match AT ALL.
 There is a boolean value to check whether we're paginating on a US Letter or
 on the only real paper size, used by the rest of the world (A4).
 
 This might have been pretty unhelpful for anyone stumbling upon this file some day.
 Try to make something out of it.
 
 NOTE NOTE NOTE:
 - Element widths are calculated using CHARACTERS PER LINE, and single character dimensions
   are... well, approximated.
 - There is a specific splitting / joining logic built into the Line class. Joining lines
   happens in the Line class, while SPLITTING is handled here. This happens in a
   very convoluted manner, with differing logic for dialogue and actions, but
   I'm looking into it.
 
 Remember the flight
 the bird may die
 (Forough Farrokhzad)
 
 
 UPDATE 2021-12-13:

 Max sizes per action line:

 A4: 59 charaters per line
 US Letter: 61 characters per line
 ... which means that one character equals 7,2 pt
 
 For now, it might be clever to base our maths on characters per line.

 */

#import <TargetConditionals.h>
#import "BeatPaginator.h"
#import "Line.h"
#import "RegExCategories.h"
#import "BeatUserDefaults.h"
#import "BeatMeasure.h"
#import "BeatAppDelegate.h"
#import "BeatFonts.h"

#if TARGET_OS_IOS
	#define BXDocument UIDocument
	#define BXPrintInfo UIPrintInfo
#else
	#define BXDocument NSDocument
	#define BXPrintInfo NSPrintInfo
#endif

#define CHARACTER_WIDTH 7.2033
#define LINE_HEIGHT 12.5

#define ACTION_A4 59
#define ACTION_US 61
#define CHARACTER 38
#define PARENTHETICAL 28
#define DIALOGUE 35

#define DUAL_DIALOGUE_A4 27
#define DUAL_DIALOGUE_US 28
#define DUAL_DIALOGUE_CHARACTER_A4 20
#define DUAL_DIALOGUE_CHARACTER_US 21
#define DUAL_DIALOGUE_PARENTHETICAL_A4 25
#define DUAL_DIALOGUE_PARENTHETICAL_US 26

@implementation BeatPage

- (instancetype)init {
	self = [super init];
	self.items = NSMutableArray.new;
	self.y = 0;
	return self;
}

- (void)clear {
	[self.items removeAllObjects];
	self.y = 0;
}

- (NSInteger)remainingSpace {
	NSInteger space = self.maxHeight - self.y;
	if (self.items.count) space -= BeatPaginator.lineHeight;
	return space;
}

- (NSInteger)remainingSpaceWithBlock:(NSArray<Line*>*)block {
	NSInteger space = self.maxHeight - self.y;
	if (self.items.count) space -= [BeatPaginator spaceBeforeForLine:block.firstObject];
	return space;
}

- (NSUInteger)count {
	return self.items.count;
}

- (void)add:(Line*)line height:(NSInteger)height {
	//if (self.items.count) self.y += [BeatPaginator spaceBeforeForLine:line];
	
	if (height == -1) {
		// This is a temporary element created for pagination (such as MORE)
		line.heightInPaginator = [self.delegate heightForBlock:@[line]];
		if (self.items.count) self.y += [BeatPaginator spaceBeforeForLine:line];
	}
	
	self.y += line.heightInPaginator;
	[self.items addObject:line];
}

- (void)addBlock:(NSArray<Line*>*)block height:(NSInteger)height {
	for (Line* line in block) {
		[self.items addObject:line];
	}
	
	//if (self.items.count) self.y += [BeatPaginator spaceBeforeForLine:block.firstObject];
	self.y += height;
}

- (NSMutableArray*)contents {
	return self.items.copy;
}

@end

@interface BeatPaginator ()

@property (weak, nonatomic) BXDocument *document;
@property (strong, nonatomic) NSArray *script;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSString *textCache;
@property bool paginating;
@property (nonatomic) bool A4;
@property (nonatomic) BXPrintInfo *printInfo;
@property (nonatomic) CGSize printableArea; // for iOS
@property (nonatomic) bool printNotes;
@property (nonatomic) BeatFont *font;

@property (nonatomic) BeatExportSettings *settings;

@property (nonatomic) NSMutableArray <NSArray<Line*>*>*pageCache;
@property (nonatomic) NSMutableArray <NSArray<Line*>*>*pageBreakCache;

@end

@implementation BeatPaginator

- (id)initWithScript:(NSArray *)elements settings:(BeatExportSettings*)settings {
	return [self initWithDocument:nil elements:elements settings:settings printInfo:nil livePagination:NO];
}

- (id)initForLivePagination:(BXDocument*)document {
	return [self initForLivePagination:document withElements:nil];
}

- (id)initForLivePagination:(BXDocument*)document withElements:(NSArray*)elements {
	return [self initWithDocument:document elements:elements settings:nil printInfo:nil livePagination:YES];
}

- (id)initWithScript:(NSArray *)elements printInfo:(BXPrintInfo*)printInfo
{
	return [self initWithDocument:nil elements:elements settings:nil printInfo:printInfo livePagination:NO];
}

- (id)initWithDocument:(BXDocument*)document elements:(NSArray*)elements settings:(BeatExportSettings*)settings printInfo:(BXPrintInfo*)printInfo livePagination:(bool)livePagination {
	self = [super init];
	if (self) {
		// We have multiple ways of setting a document.
		// Live pagination uses document parameter, while export sends it via settings.
		if (document) _document = document;
		else if (settings.document) _document = settings.document;
		else _document = nil;
		
		_pages = NSMutableArray.new;
		_script = (elements.count) ? elements : NSArray.new;
		_printInfo = (printInfo) ? printInfo : nil;
		_pageBreaks = NSMutableArray.new;
		_livePagination = livePagination;
		_settings = settings;
		_printNotes = (settings) ? settings.printNotes : NO;
		
		_font = [BeatFont fontWithName:@"Courier" size:12];
	}
	
	return self;
}


// Experimental new live pagination

- (NSInteger)findSafePageFrom:(NSInteger)location actualIndex:(NSInteger*)actualIndex {
	// Find current line based on the index
	NSMutableArray *currentPage;
	
	bool pageFound = false;
	for (NSMutableArray *page in _pages) {
		for (Line* line in page) {
			if (location >= line.position) {
				currentPage = page;
				pageFound = true;
				break;
			}
		}
		
		if (pageFound) break;
	}
		
	// No page found
	if (!currentPage) return NSNotFound;
	
	// Find the index of the page on which our current line is on
	NSInteger pageIndex = [_pages indexOfObject:currentPage];
	
	// Iterate pages backwards
	for (NSInteger p = pageIndex; p >=0; p--) {
		NSMutableArray *page = _pages[p];

		Line *firstLine = page.firstObject;
		
		// Check if this line is a safe place to start the pagination
		if (!firstLine.unsafeForPageBreak) {
			if (p > 0) {
				NSMutableArray *prevPage = _pages[p - 1];
				NSInteger lastIndex = prevPage.count - 1;
				
				// Find the next actual line and its position.
				while (lastIndex >= 0) {
					Line *lastLine = prevPage[lastIndex];
					if (lastLine.type != more && lastLine.type != dualDialogueMore) {
						*actualIndex = NSMaxRange(lastLine.range);
						return p;
					}
					lastIndex--;
				}
			}
		}
	}
	
	return NSNotFound;
}

- (void)livePaginationFor:(NSArray*)script changeAt:(NSUInteger)location {
	@synchronized (self) {
		self.script = script;
		_paginating = YES;
		
		// Make backups of the results
		self.pageCache = self.pages.copy;
		self.pageBreakCache = self.pageBreaks.copy;
				
		NSInteger actualIndex = NSNotFound;
		NSInteger safePageIndex = [self findSafePageFrom:location actualIndex:&actualIndex];
		
		NSInteger startIndex = 0;
		
		if (safePageIndex != NSNotFound && safePageIndex > 0 && actualIndex != NSNotFound) {
			_pages = [_pages subarrayWithRange:(NSRange){0, safePageIndex}].mutableCopy;
			_pageBreaks = [_pageBreaks subarrayWithRange:(NSRange){0, safePageIndex + 1}].mutableCopy; // +1 so we include the first, intial page break
						
			startIndex = actualIndex;
		} else {
			_pages = NSMutableArray.new;
			_pageBreaks = NSMutableArray.new;
		}
	
		[self paginateFromIndex:startIndex];
	}
}

- (NSArray *)pageAtIndex:(NSUInteger)index
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if (self.pages.count == 0) [self paginate];
	
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
#if TARGET_OS_IOS
	_paperSize = [BeatPaperSizing printableAreaFor:pageSize];
#else
	_printInfo = [BeatPaperSizing printInfoFor:pageSize];
#endif
}


- (void)setScript:(NSArray *)script {
	NSMutableArray *lines = [NSMutableArray array];
	
	for (Line *line in script) {
		if (line.type == empty || line.omitted) continue;
		
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
	self.pages = NSMutableArray.new;
	[self paginateFromIndex:0];
}

- (void)useCachedPaginationFrom:(NSInteger)pageIndex {
	[self.pages removeLastObject];
	[self.pageBreaks removeLastObject];
	
	NSArray *cachedPages = [self.pageCache subarrayWithRange:NSMakeRange(pageIndex, self.pageCache.count - pageIndex - 1)];
	[self.pages addObjectsFromArray:cachedPages];
	
	NSArray *cachedLineBreaks = [self.pageBreakCache subarrayWithRange:NSMakeRange(pageIndex + 1, self.pageBreakCache.count - pageIndex - 1)];
	[self.pageBreaks addObjectsFromArray:cachedLineBreaks];
}

- (void)getPaperSizeFromDocument {
	/**
	 
	 We have separate code for macOS and iOS here. The reason is that NSPrintInfo automatically
	 conforms to the default printer, and you can set the paper size through NSPrintInfo.
	 
	 On iOS, we'll fetch our imaginary printable area, based on expor settings and use that as page size.
	 
	 */
#if !TARGET_OS_IOS
	// macOS paper sizing
	
	if (_document || _printInfo) {
		BXPrintInfo *printInfo;
		if (_document) printInfo = _document.printInfo.copy;
		else printInfo = _printInfo.copy;
			
		printInfo = [BeatPaperSizing setMargins:printInfo];
				
		CGFloat w = roundf(printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin);
		CGFloat h = roundf(printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin);
		
		// Printer can't print this high a page, so let's reduce page height
		if (printInfo.imageablePageBounds.size.height < h) {
			h = printInfo.imageablePageBounds.size.height;
		}

		_paperSize = CGSizeMake(w, h);
	} else {
		_paperSize = CGSizeMake(595, 821);
	}
	
#else
	// iOS paper sizing
	_paperSize = [BeatPaperSizing printableAreaFor:_settings.paperSize];
#endif
	
}

- (void)paginateFromIndex:(NSInteger)fromIndex
{
	if (!self.script.count) return;
	
	if (!_livePagination) {
		// Make lines know their paginator
		for (Line* line in self.script) line.paginator = self;
		self.pages = NSMutableArray.new;
	}
	
	[self getPaperSizeFromDocument];
			
	CGFloat spaceBefore = 0;
	//NSInteger currentY = 0;
	
	NSInteger oneInchBuffer = 72;
	NSInteger maxPageHeight = _paperSize.height - round(oneInchBuffer);
	
	CGFloat lineHeight = LINE_HEIGHT;
	
	BeatPage *currentPage = BeatPage.new;
	currentPage.maxHeight = maxPageHeight;
	currentPage.delegate = self;
	
	bool hasStartedANewPage = NO;

	
	// create a tmp array that will hold elements to be added to the pages
	NSMutableArray *tmpElements = [NSMutableArray array];
	
	
	// Walk through the elements array and place them on pages.
	for (NSInteger i = 0; i < self.script.count; i++) { @autoreleasepool {
		if (!_paginating && _livePagination) {
			// An experiment in canceling background-thread pagination
			[self cancel];
			return;
		}
		
		Line *element  = self.script[i];
		
		// Skip element if it's not in the specified range for pagination
		if (fromIndex > 0 && NSMaxRange(element.textRange) < fromIndex) continue;
	
		// If the element is already in the queue, continue. Otherwise flush the queue.
		if ([tmpElements containsObject:element]) continue;
		else [tmpElements removeAllObjects];
		
		// Skip invisible elements (unless we are printing notes)
		if (element.type == empty) continue;
		else if (element.isInvisible) {
			if (!(_settings.printNotes && element.note)) continue;
		}
		
		// If this is the FIRST page, add a break to mark for the end of title page and beginning of document
		if (_pageBreaks.count == 0 && _livePagination) [self pageBreak:element position:0 type:@"First page"];
		
		// If we've started a new page since we began paginating, see if the rest of the page is intact.
		// If so, we can just use our cached results.
		if (hasStartedANewPage && currentPage.count == 0 &&
			!element.unsafeForPageBreak && _pageCache.count >= self.pages.count) {
			Line *firstLineOnCachedPage = _pageCache[self.pages.count-1].firstObject;
			
			if (firstLineOnCachedPage.uuid == element.uuid) {
				[self useCachedPaginationFrom:self.pages.count - 1];
				// Stop pagination
				break;
			}
		}

		// Reset Y if the page is empty.
		if (currentPage.count == 0) {
			//currentY = 0;
			hasStartedANewPage = YES;
		}
		
		// catch forced page breaks first
		if (element.type == pageBreak) {
			[self resetPage:currentPage onCurrentPage:@[element] onNextPage:@[]];
			[self pageBreak:element position:-1 type:@"Forced page break"];
			continue;
		}
		
		
		#pragma mark Calculate block height
		
		// Catch wrong parsing.
		// We SHOULD NOT have orphaned dialogue. This can happen with live pagination, though.
		if (element.type == dialogue && element.string.length == 0) continue;
		 
		// Get whole block
		NSArray *block = [self blockFor:element];
		
		// Calculate block height
		NSInteger fullHeight = [self heightForBlock:block page:currentPage];
		if (fullHeight <= 0) continue; // Ignore this block if it's empty
		
		// Save space before for this line (why?)
		spaceBefore = [BeatPaginator spaceBeforeForLine:element];
		
		// Add whole block into temporary element queue
		[tmpElements addObjectsFromArray:block];

		// Fix to get styling to show up in PDFs. I have no idea.
		// (wtf is this, wondering in 2022. Might originate from the original Fountain repo)
		if (![element.string isMatch:RX(@" $")]) element.string = [NSString stringWithFormat:@"%@%@", element.string, @""];
		
		
		#pragma mark Break elements onto pages
		
		// BREAKING ELEMENTS ONTO PAGES
		// Figure out which element went overboard
		if (currentPage.y + fullHeight > maxPageHeight) {
			CGFloat overflow = maxPageHeight - (currentPage.y + fullHeight);
			
			// If it fits, just squeeze it on this page
			if (fabs(overflow) <= lineHeight * 1.05) {
				[self resetPage:currentPage onCurrentPage:tmpElements onNextPage:@[]];
				[self pageBreak:(Line*)tmpElements.lastObject position:-1 type:@"Generally squeezed"];
				continue;
			}
			
			// Find out the spiller
			Line *spillerElement;
			
			bool handled = NO;
			
			#pragma mark Split scene heading & paragraph
			// NOTE TO SELF: This does NOT go well when the heading is followed by something else than action
			// We should use blockFor:(Line*)line
			
			if (element.type == heading || element.type == action) {
				bool headingBlock = NO;
				
				// If it's a scene heading, spiller element is the line after heading line
				if (element.type == heading) {
					headingBlock = YES;
					
					if (block.count > 1) spillerElement = block.lastObject;
					else spillerElement = element;
											
					// Push to next page if it the split would be only 1 line or something
					if ((fullHeight - fabs(overflow) < lineHeight * 4.5
						&& fabs(overflow) >= lineHeight) ||
						fabs(overflow) < lineHeight * 2) {
						handled = YES;
					}
				} else {
					spillerElement = element;
				}
									
				// Split first paragraph scene into two if it's higher than one line
				NSInteger limit = lineHeight;
				NSInteger space = maxPageHeight - currentPage.y;
				
				if (fabs(overflow) > limit && space > limit * 2 && !handled) {
					NSMutableArray *words = [spillerElement.stripFormatting componentsSeparatedByString:@" "].mutableCopy;
					
					NSInteger space = maxPageHeight - currentPage.y;
					
					// We substract heading line height from the remaining space
					if (headingBlock) space -= [self heightForBlock:@[element] page:currentPage];
					
					NSMutableString *text = [NSMutableString stringWithString:@""];
					NSMutableString *retain = [NSMutableString stringWithString:@""];
					NSMutableString *split = [NSMutableString stringWithString:@""];
					
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
						
						if (wordIndex == 0) [text appendFormat:@"%@", word];
						else {
							// This is a very quick and dirty fix for weird edge cases
							if (word.length) {
								if ([word characterAtIndex:word.length-1] == '\n') [text appendFormat:@"%@", word];
								else [text appendFormat:@" %@", word];
							}
							else [text appendFormat:@" %@", word];
						}
						
						Line *tempElement = [[Line alloc] initWithString:text type:action];
						
						NSInteger h = [self elementHeight:tempElement lineHeight:lineHeight];
						if (h < space) {
							breakPosition = h;
							if (wordIndex == 0) [retain appendFormat:@"%@", word];
							else if (word.length) {
								if ([word characterAtIndex:word.length-1] == '\n') [retain appendFormat:@"%@", word];
								else [retain appendFormat:@" %@", word];
							}
							else [retain appendFormat:@" %@", word];
						} else {
							[split appendFormat:@" %@", word];
						}
					}
					
					NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
					Line *prePageBreak = splitElements[0];
					Line *postPageBreak = splitElements[1];

					// If it's a heading we need special rules
					if (headingBlock) {
						// We had something remain on the original page
						if (retain.length) {
							[self resetPage:currentPage onCurrentPage:@[element, prePageBreak] onNextPage:@[postPageBreak]];
							[self pageBreak:spillerElement position:breakPosition type:@"Heading block"];
						}
						// Nothing remained, move whole scene heading to next page
						else {
							[self resetPage:currentPage onCurrentPage:@[] onNextPage:@[element, postPageBreak]];
							[self pageBreak:element position:0 type:@"Heading block moved on next page"];
						}
					} else {
						[self resetPage:currentPage onCurrentPage:@[prePageBreak] onNextPage:@[postPageBreak]];
						[self pageBreak:spillerElement position:breakPosition type:@"Action or heading"];
					}
											
					continue;
					
				} else {
					// Reset page and go on
					[self resetPage:currentPage onCurrentPage:@[] onNextPage:tmpElements];
					// Add page break info (for live pagination if in use)
					[self pageBreak:element position:0 type:@"Unknown"];
					continue;
				}
			}
			
			#pragma mark Split dialogue
			// This is a convoluted system because of the way Fountain handles dual dialogue.
			// Try to keep up.
			
			else if (element.type == character || element.type == dualDialogueCharacter) {
				NSMutableArray *retainedLines = NSMutableArray.array;
				NSMutableArray *nextPageLines = NSMutableArray.array;
				
				Line *pageBreakElement;
				NSInteger pageBreakPosition = 0;
								 
				// Normal, single dialogue
				if (!element.nextElementIsDualDialogue) {
					Line *spillEl = [self findDialogueSpiller:block page:currentPage];
					
					//NSDictionary *split = [self splitDialogue:block spiller:spillEl remainingSpace:remainingSpace height:[self heightForDialogueBlock:block page:currentPage]];
					NSDictionary *split = [self splitDialogue:block spiller:spillEl page:currentPage];

					if ([(NSArray*)split[@"retained"] count]) {
						[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
						
						pageBreakElement = (Line*)split[@"page break item"];
						pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
						
						[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
					} else {
						pageBreakElement = block.lastObject;
						[nextPageLines addObjectsFromArray:block];
					}
				}
				
				// Split dual dialogue (this is a *bit* more complicated)
				else if (element.nextElementIsDualDialogue) {
					NSArray *dual = [self separateDualDialogue:block];
					
					bool leftSideFits = NO;
					bool rightSideFits = NO;
					
					Line *spillEl = [self findDialogueSpiller:dual[0] page:currentPage];
					Line *spillEl2 = [self findDialogueSpiller:dual[1] page:currentPage];
									
					if (!spillEl) leftSideFits = YES;
					if (!spillEl2) rightSideFits = YES;
										
					NSDictionary *split;
					
					if (leftSideFits && !rightSideFits) {
						// Left side fits, split right side
						//split = [self splitDialogue:dual[1] spiller:spillEl2 remainingSpace:remainingSpace height:[self heightForDialogueBlock:dual[1] page:currentPage]];
						split = [self splitDialogue:dual[1] spiller:spillEl2 page:currentPage];
						
						// If there is something to retain, do it, otherwise just push everything on the next page
						if ([(NSArray*)split[@"retained"] count]) {
							[retainedLines addObjectsFromArray:dual[0]];
							[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
							
							pageBreakElement = (Line*)split[@"page break item"];
							pageBreakPosition = [(NSNumber*)split[@"position"] integerValue];
							
							[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
						} else {
							[nextPageLines setArray:block];
							pageBreakElement = nextPageLines.firstObject;
						}
					}
					else if (!leftSideFits && rightSideFits) {
						// Right side firts, split left side
						
						split = [self splitDialogue:dual[0] spiller:spillEl2 page:currentPage];
						
						// If there is something to retain, do it, otherwise just push everything on the next page
						if ([(NSArray*)split[@"retained"] count]) {
							[retainedLines addObjectsFromArray:(NSArray*)split[@"retained"]];
							[retainedLines addObjectsFromArray:dual[1]];
							
							pageBreakElement = (Line*)split[@"page break item"];
							pageBreakPosition = ((NSNumber*)split[@"position"]).integerValue;
							
							[nextPageLines addObjectsFromArray:(NSArray*)split[@"next page"]];
						} else {
							[nextPageLines setArray:block];
							pageBreakElement = nextPageLines.firstObject;
						}
					}
					else if (!leftSideFits && !rightSideFits) {
						// Split BOTH dialogue blocks
						NSArray *leftDialogue = dual[0];
						NSArray *rightDialogue = dual[1];
						
						NSDictionary *splitLeft = [self splitDialogue:leftDialogue spiller:spillEl page:currentPage];
						NSDictionary *splitRight = [self splitDialogue:rightDialogue spiller:spillEl2 page:currentPage];
						
						// Figure out where to put the actual page break
						NSArray *retainLeft = (NSArray*)splitLeft[@"retained"];
						NSArray *retainRight = (NSArray*)splitRight[@"retained"];
						NSArray *nextPageLeft = (NSArray*)splitLeft[@"next page"];
						NSArray *nextPageRight = (NSArray*)splitRight[@"next page"];
						
						// If both sides have somethign to retain, do it
						if (retainLeft.count && retainRight.count) {
							[retainedLines addObjectsFromArray:retainLeft];
							[retainedLines addObjectsFromArray:retainRight];
							
							[nextPageLines addObjectsFromArray:nextPageLeft];
							[nextPageLines addObjectsFromArray:nextPageRight];
							
							pageBreakElement = nextPageLines[1];
						} else {
							[nextPageLines setArray:block];
							pageBreakElement = nextPageLines.firstObject;
						}
					}
				}
				
				[self resetPage:currentPage onCurrentPage:retainedLines onNextPage:nextPageLines];
				[tmpElements setArray:block]; // Ignore rest of the unprocessed block
				
				// Add page break for live pagination
				if (retainedLines.count) [self pageBreak:pageBreakElement position:pageBreakPosition type:@"Dialogue"];
				else [self pageBreak:block.firstObject position:0 type:@"Dialogue moved on next page"];
				
				continue;
			} else {
				// Whatever, let's just push this element on the next page
				// Reset page
				[self resetPage:currentPage onCurrentPage:@[] onNextPage:@[element]];
								
				// I'm pretty sure there will never be spiller element, but anyway
				if (!spillerElement) spillerElement = element;
				
				[self pageBreak:spillerElement position:0 type:@"Unknown dialogue page beak"];
				continue;
			}
		}
			
	
		#pragma mark Add elements in queue on page
		
		[currentPage addBlock:tmpElements height:fullHeight];
		
	} } // Autoreleasepool end
	
	// Add the last page
	[_pages addObject:currentPage.contents];
	
	// Remove last page if it's empty
	NSArray *lastPage = _pages.lastObject;
	if (lastPage.count == 0) [_pages removeLastObject];
		
	_lastPageHeight = (float)currentPage.y / (float)maxPageHeight;
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

- (CGFloat)elementHeight:(Line *)element lineHeight:(CGFloat)lineHeight {
	NSString *string = element.stripFormatting;
	return [BeatPaginator heightForString:string font:_font maxWidth:[self widthForElement:element] lineHeight:lineHeight];
}

- (NSInteger)cplToWidth:(Line*)element {
	// Characters per line to with
	NSInteger cpl = 0;
	
	switch (element.type) {
		case dialogue:
			cpl = DIALOGUE; break;
		case character:
			cpl = CHARACTER; break;
		case parenthetical:
			cpl = PARENTHETICAL; break;
		case dualDialogue:
			if (_settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_A4;
			else cpl = DUAL_DIALOGUE_US;
			break;
		case dualDialogueCharacter:
			if (_settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_CHARACTER_A4;
			else cpl = DUAL_DIALOGUE_CHARACTER_US;
			break;
		case dualDialogueParenthetical:
			if (_settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_PARENTHETICAL_A4;
			else cpl = DUAL_DIALOGUE_US;
			break;
			
		default:
			if (_settings.paperSize == BeatA4) cpl = ACTION_A4;
			else cpl = ACTION_US;
			break;
	}
	
	CGFloat width = cpl * CHARACTER_WIDTH;
	
	// Make space for scene number
	if (element.type == heading) width -= 25.0;
	
	return (NSInteger)(roundf(width));
}

- (NSInteger)widthForElement:(Line *)element
{
	return [self cplToWidth:element];
}

/**
 To get the height of a string we need to create a text layout box, and use that to calculate the number
 of lines of text we have, then multiply that by the line height. This is NOT the method Apple describes
 in their docs, but we have to do this because getting the size of the layout box returns strange values.
 */
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight
{
	/*
	 This method MIGHT NOT work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	
	if (string.length == 0) return lineHeight;
	if (font == nil) font = BeatFonts.sharedFonts.courier;
	
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
	font = [font fontWithSize:font.pointSize * 0.8];
#endif

	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = NSLayoutManager.new;

	NSTextContainer *textContainer = NSTextContainer.new;
	[textContainer setSize:CGSizeMake(maxWidth, MAXFLOAT)];

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
	else if (line.type == heading) {
		// Get user default for scene heading spacing
		NSInteger spacingBeforeHeading = [BeatUserDefaults.sharedDefaults getInteger:@"sceneHeadingSpacing"];
		return LINE_HEIGHT * spacingBeforeHeading;
	}
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

#pragma mark - Dialogue methods

- (NSArray*)dialogueBlockFor:(Line*)element {
	// This is old and not too elegant, but whatever
	
	NSInteger i = [self.script indexOfObject:element];
	NSInteger startIndex = i;
	NSMutableArray <Line*>* block = NSMutableArray.new;
	
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
	/**
	 This finds the screenplay block for an element.
	 
	 It can be either a DIALOGUE (including its dual dialogue sibling), single action, or heading + action.
	 The behavior should be expanded so that a heading will ALSO retrieve its following item, be it a dialogue block or something else.
	 I'm unsure how that would affect the surrounding logic.
	*/
	
	if (line.isAnyCharacter) return [self dialogueBlockFor:line];
	else if (line == self.script.lastObject) return @[line];
	else if (line.type != heading) return @[line];
	
	NSMutableArray *block = NSMutableArray.new;
	
	NSInteger i = [self.script indexOfObject:line];
	if (i == self.script.count - 1) return @[line];

	NSInteger l = i + 1;
	[block addObject:line];
	
	while (l < self.script.count) {
		Line *el = self.script[l];

		if (el.type == empty || el.string.length == 0) {
			l++;
			continue;
		}
		
		if (el.type == action) {
			[block addObject:el];
			break;
		}
		else break;
	}
	
	return block;
}

- (NSInteger)heightForBlock:(NSArray*)block {
	return [self heightForBlock:block page:nil];
}

- (NSInteger)heightForBlock:(NSArray<Line*>*)block page:(BeatPage*)currentPage {
	if (block.firstObject.isDialogue || block.firstObject.isDualDialogue) {
		return [self heightForDialogueBlock:block page:currentPage];
	}
	
	NSInteger fullHeight = 0;
		
	for (Line *line in block) {
		CGFloat spaceBefore = 0;
		if (currentPage.count || line != block.firstObject) spaceBefore = [BeatPaginator spaceBeforeForLine:line];
		
		CGFloat elementWidth = [self widthForElement:line];
		NSInteger height = [BeatPaginator heightForString:line.stripFormatting font:_font maxWidth:elementWidth lineHeight:LINE_HEIGHT];
		fullHeight += spaceBefore + height;
		
		line.heightInPaginator = height;
	}
	

	return fullHeight;
}

- (NSInteger)heightForDialogueBlock:(NSArray<Line*>*)block page:(BeatPage*)currentPage {
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
		
		NSInteger height = [self elementHeight:line lineHeight:LINE_HEIGHT];
		line.heightInPaginator = height;
		
		dialogueBlockHeight += height;
	}
		
	// Set the height to be the longer one
	if (previousDialogueBlockHeight > dialogueBlockHeight) dialogueBlockHeight = previousDialogueBlockHeight;
	
	if (currentPage.count > 0) {
		dialogueBlockHeight += [BeatPaginator spaceBeforeForLine:block.firstObject];
	}
	
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

- (Line*)findDialogueSpiller:(NSArray*)dialogueBlock page:(BeatPage*)page {
	Line* spillerElement;
	NSInteger dialogueHeight = 0;
	NSUInteger remainingSpace = page.remainingSpace;
	
	for (Line *line in dialogueBlock) {
		NSInteger h = [self elementHeight:line lineHeight:LINE_HEIGHT];
		
		if (dialogueHeight + h > remainingSpace) {
			spillerElement = line;
			break;
		}
		else {
			dialogueHeight += h;
		}
	}
		
	return spillerElement;
}


#pragma mark New dialogue split implementation
- (NSDictionary*)splitDialogue:(NSArray<Line*>*)block spiller:(Line*)spiller page:(BeatPage*)page {
	NSMutableArray *dialogueBlock = block.mutableCopy;
	/*
	static BeatAppDelegate *delegate;
	if (delegate == nil) {
		delegate = (BeatAppDelegate*)NSApp.delegate;
		[delegate openConsole];
	}
	 */
	
	Line *pageBreakItem;
	NSUInteger suggestedPageBreak = 0;
		
	NSUInteger index = [dialogueBlock indexOfObject:spiller];
	NSInteger remainingSpace = page.remainingSpace;
	
	if (spiller) {
		// Spiller can be null, if we're in a dual-dialogue block
		NSArray *blockUntilSpiller = [dialogueBlock subarrayWithRange:NSMakeRange(0, index)];
		remainingSpace -= [self heightForBlock:blockUntilSpiller];
	}
		
	// Arrays for elements
	NSMutableArray *onThisPage = NSMutableArray.new;
	NSMutableArray *onNextPage = NSMutableArray.new;
	// Arrays for faux elements which are created while paginating
	NSMutableArray *tmpThisPage = NSMutableArray.new;
	NSMutableArray *tmpNextPage = NSMutableArray.new;
	
	// Indices in which we could split the block.
	// When we can't split the block at current item, we'll fall back to the previous possible index.
	NSIndexSet *splittableIndices = [self possiblePageSplitIndicesInDialogueBlock:dialogueBlock];
	
	// Split the block at this location
	NSUInteger splitAt = (index > 0) ? [splittableIndices indexLessThanOrEqualToIndex:index] : 0;
	
	// Live pagination page break item
	pageBreakItem = block[splitAt];


	// For dialogue, we'll see if we can split the current line of dialogue
	if (spiller.isAnyDialogue) {
		if (remainingSpace > BeatPaginator.lineHeight) {
			// Split dialogue according to remaining space
			NSArray <NSString*>* splitLine = [self splitDialogueLine:spiller remainingSpace:remainingSpace pageBreakPosition:&suggestedPageBreak];
			NSString *retainStr = splitLine[0];
			
			if (retainStr.length > 0) {
				NSArray <Line*>*splitElements = [spiller splitAndFormatToFountainAt:retainStr.length];

				[tmpThisPage addObject:splitElements[0]];
				[tmpNextPage addObject:splitElements[1]];
				pageBreakItem = spiller;
				
				[dialogueBlock removeObject:spiller];
			} else {
				// Nothing fit
				splitAt = [splittableIndices indexLessThanIndex:splitAt];
				pageBreakItem = block[splitAt];
			}
		}
		else {
			// This line of dialogue does not fit on page
			splitAt = [splittableIndices indexLessThanIndex:splitAt];
			pageBreakItem = block[splitAt];
		}
	}
		
	// Don't allow only a single element to stay on page
	if (splitAt == 1 && tmpThisPage.count == 0) splitAt = 0;
	
	// If something is left behind on the current page, split it
	if (splitAt > 0) {
		// Don't allow the last element in block to be parenthetical
		Line *prevElement = block[splitAt - 1];
		if (prevElement.isAnyParenthetical && tmpThisPage.count == 0) splitAt -= 1;
		
		// Split the block
		[onThisPage addObjectsFromArray:
			 [block subarrayWithRange:NSMakeRange(0, splitAt)]
		];
		[onThisPage addObjectsFromArray:tmpThisPage];
		[onThisPage addObject:[BeatPaginator moreLineFor:spiller]];
	}
			
	// Add stuff on next page if needed
	if (onThisPage.count) [onNextPage addObject:[BeatPaginator contdLineFor:dialogueBlock.firstObject]];
	[onNextPage addObjectsFromArray:tmpNextPage];
	NSRange splitRange = NSMakeRange(splitAt, dialogueBlock.count - splitAt);
	if (splitRange.length > 0) [onNextPage addObjectsFromArray:[dialogueBlock subarrayWithRange:splitRange]];
	
	/*
	if (!_livePagination) {
		[delegate logToConsole:[NSString stringWithFormat:@"Result: %lu", splitAt] pluginName:@"Pagination"];
		[delegate logToConsole:[NSString stringWithFormat:@"Temp objects created: %@", tmpThisPage] pluginName:@"Pagination"];
		[delegate logToConsole:[NSString stringWithFormat:@"Remaining: %@", onThisPage] pluginName:@"Pagination"];
		[delegate logToConsole:[NSString stringWithFormat:@"Paginated: %@", onNextPage] pluginName:@"Pagination"];
	}
	 */
	
	NSDictionary *result =  @{
		@"page break item": pageBreakItem,
		@"position": @(suggestedPageBreak),
		@"retained": onThisPage,
		@"next page": onNextPage
	};
	
	return result;
}

- (NSIndexSet*)possiblePageSplitIndicesInDialogueBlock:(NSArray<Line*>*)block {
	NSMutableIndexSet *possibleSplit = [NSMutableIndexSet indexSetWithIndex:0];
	
	for (NSInteger i=0; i<block.count; i++) {
		Line *line = block[i];
	
		// Any parenthetical after the first one are good places to break the page
		if (line.isAnyParenthetical && i > 1) [possibleSplit addIndex:i];
		// Any line of dialogue is a good place to attempt to break the page
		if (line.isAnyDialogue) [possibleSplit addIndex:i];
	}
	
	return possibleSplit;
}

- (NSArray*)splitDialogueLine:(Line*)line remainingSpace:(NSUInteger)remainingSpace pageBreakPosition:(NSUInteger*)suggestedPageBreak
{
	/// Returns an array with [retainedText, splitText]

	NSString *stripped = line.stripFormatting;
	NSMutableArray *sentences = [NSMutableArray arrayWithArray:[stripped matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
	
	// Make sure we are not missing anything
	NSString *joined = [sentences componentsJoinedByString:@""];
	NSString *tail = [stripped stringByReplacingOccurrencesOfString:joined withString:@""];
	if (tail.length > 0) [sentences addObject:tail];
	if (!sentences.count && stripped.length) [sentences addObject:stripped];
	
	NSString *text = @"";
	NSMutableString *retain = [NSMutableString stringWithString:@""];
	NSMutableString *split = [NSMutableString stringWithString:@""];
	CGFloat breakPosition = 0;
	
	int sIndex = 0;
	bool forceNextpage = NO;
			
	for (NSString *rawSentence in sentences) {
		NSString *sentence = rawSentence;
		// Trim whitespace for the last object
		//if (rawSentence == sentences.lastObject) sentence = [sentence stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

		text = [text stringByAppendingFormat:@"%@", sentence];
		
		// Create a temporary element and fetch its height
		Line *tempElement = [Line withString:text type:dialogue];
		NSInteger h = [self elementHeight:tempElement lineHeight:LINE_HEIGHT];
		
		if (h + BeatPaginator.lineHeight > remainingSpace && !forceNextpage) {
			// If there is space left for less than a single line, avoid trying to squeeze stuff in,
			// and let it flow onto the next page.
			breakPosition = h;
			remainingSpace -= LINE_HEIGHT;
			
			forceNextpage = YES;
		}
		
		if (h < remainingSpace) {
			breakPosition = h;
			[retain appendFormat:@"%@", sentence];
		} else {
			[split appendFormat:@"%@", sentence];
		}
		
		sIndex++;
	}
	
	// Set the pointer to correct y position
	*suggestedPageBreak = round(breakPosition);
	
	return @[retain, split];
}

#pragma mark - Reset page
 
- (void)resetPage:(BeatPage*)currentPage onCurrentPage:(NSArray*)prevPageItems onNextPage:(NSArray*)nextPageItems {
	// Global page reset

	if (prevPageItems.count) [currentPage addBlock:prevPageItems height:0]; // No need to calculate height for these elements
	[_pages addObject:currentPage.contents];
	
	[currentPage clear];
	
	// Let's run the next page block through height calculator, so its line objects get the correct height.
	NSInteger nextPageHeight = [self heightForBlock:nextPageItems];
	if (nextPageItems.count) [currentPage addBlock:nextPageItems height:nextPageHeight];
}

#pragma mark - More / Cont'd items

+ (Line*)contdLineFor:(Line*)line {
	NSString *extension = [BeatPaginator contdString];
	NSString *cue = [line.stripFormatting stringByReplacingOccurrencesOfString:extension withString:@""];
	cue = [cue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	NSString *contdString = [NSString stringWithFormat:@"%@%@", cue, extension];
	Line *contd = [Line.alloc initWithString:contdString type:character];
	contd.nextElementIsDualDialogue = line.nextElementIsDualDialogue;
	if (line.type == dualDialogueCharacter) contd.type = dualDialogueCharacter;
	
	return contd;
}

+ (Line*)moreLineFor:(Line*)line {
	LineType type = (line.isDualDialogue) ? dualDialogueMore : more;
	Line *more = [Line.alloc initWithString:[BeatPaginator moreString] type:type];
	more.unsafeForPageBreak = YES;
	return more;
}

+ (NSString*)moreString {
	NSString *moreStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemMore"];
	return [NSString stringWithFormat:@"(%@)", moreStr];
}
+ (NSString*)contdString {
	NSString *contdStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemContd"];
	return [NSString stringWithFormat:@" (%@)", contdStr]; // Extra space here to be easily able to add this after a cue
}

#pragma mark - Additional convenience methods

- (bool)boolForKey:(NSString*)key {
	id value = [self valueForKey:key];
	return [(NSNumber*)value boolValue];
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
