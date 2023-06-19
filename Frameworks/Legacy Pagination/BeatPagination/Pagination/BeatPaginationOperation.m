//
//  BeatPaginationOperation.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class takes care of the *actual* pagination.
 
 NOTE NOTE NOTE:
 - Element widths are calculated using CHARACTERS PER LINE, and single character dimensions
   are... well, approximated.
 - There is a specific splitting / joining logic built into the Line class. Joining lines
   happens in the Line class, while SPLITTING is handled here. This happens in a
   very convoluted manner, with differing logic for dialogue and actions.

 
 Max sizes per action line:

 A4: 59 charaters per line
 US Letter: 61 characters per line
 ... which means that one character equals 7,2 px
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatPaginationOperation.h"
#import "BeatPaginator.h"
#import "BeatPage.h"
#import <BeatCore/BeatFonts.h>


#define CHARACTER_WIDTH 7.2033

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


@interface BeatPaginationOperation ()

@property (nonatomic) bool stop;

@property (atomic) NSMutableArray *elementQueue;

@property (atomic) BeatPrintInfo *printInfo;
@property (atomic) CGSize printableArea; // for iOS

@property (nonatomic) NSArray <NSArray*>* pageCache;
@property (nonatomic) NSArray <NSDictionary*>* pageBreakCache;

@property (nonatomic) CGSize paperSize;

@end

@implementation BeatPaginationOperation

- (id)initWithElements:(NSArray *)elements paginator:(id<BeatPaginationOperationDelegate>)paginator {
	return [BeatPaginationOperation.alloc initWithElements:elements livePagination:false paginator:paginator cachedPages:nil cachedPageBreaks:nil changeAt:0];
}

- (id)initWithElements:(NSArray*)elements livePagination:(bool)livePagination paginator:(id<BeatPaginationOperationDelegate>)paginator cachedPages:(NSArray*)cachedPages cachedPageBreaks:(NSArray*)cachedBreaks changeAt:(NSInteger)changeAt {
	self = [super init];
	if (self) {
		self.paginator = paginator;
		
		self.pages = NSMutableArray.new;
		self.pageBreaks = NSMutableArray.new;

		self.script = (elements.count > 0) ? elements : @[];
		self.livePagination = livePagination;
		
		self.pageCache = cachedPages.copy;
		self.pageBreakCache = cachedBreaks.copy;
		
		self.location = changeAt;
				
		if (!NSThread.isMainThread) _thread = NSThread.currentThread;
	}
	
	return self;
}

- (void)cancel {
	self.cancelled = true;
	//[_thread cancel];
}

#pragma mark - Running pagination

- (void)paginate {
	_running = true;
	
	self.pages = NSMutableArray.new;
	self.pageBreaks = NSMutableArray.new;
	
	_success = [self paginateFromIndex:0];
	[self paginationFinished];
}
- (void)paginateForEditor {
	_running = true;
	
	NSInteger actualIndex = NSNotFound;
	NSInteger safePageIndex = [self findSafePageFrom:_location actualIndex:&actualIndex];
	
	NSInteger startIndex = 0;
	
	if (safePageIndex != NSNotFound && safePageIndex > 0 && actualIndex != NSNotFound) {
		self.pages = [self.pageCache subarrayWithRange:(NSRange){0, safePageIndex}].mutableCopy;
		self.pageBreaks = [self.pageBreakCache subarrayWithRange:(NSRange){0, safePageIndex + 1}].mutableCopy; // +1 so we include the first, intial page break
					
		startIndex = actualIndex;
	} else {
		self.pages = NSMutableArray.new;
		self.pageBreaks = NSMutableArray.new;
	}

	_success = [self paginateFromIndex:startIndex];
	
	[self paginationFinished];
}

- (void)paginationFinished {
	@try {
		[self.paginator paginationFinished:self];
	}
	@catch (NSException *e) {
		NSLog(@"Failed to return pagination results: %@", e);
	}
}

- (NSUInteger)numberOfPages
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if (self.pages.count == 0) [self paginateFromIndex:0];
	return self.pages.count;
}


#pragma mark Finding safe page for live pagination

- (NSInteger)findSafePageFrom:(NSInteger)location actualIndex:(NSInteger*)actualIndex {
	// Find current line based on the index
	NSMutableArray *currentPage;
	
	bool pageFound = false;
	NSMutableArray* prevPage;
	for (NSMutableArray *page in self.pages) {
		for (Line* line in page) {
			if (line.position > location) {
				// We reached a page in the given range.
				// If this is the *first* line on that page, we need to return the previous page.
				if (line != page.firstObject) {
					currentPage = page;
					pageFound = true;
					break;
				} else {
					if (prevPage) currentPage = prevPage;
					pageFound = true;
					break;
				}
			}
		}
		
		prevPage = page;
		if (pageFound) break;
	}
	
	// No page found
	if (currentPage == nil) return NSNotFound;
	
	// Find the index of the page on which our current line is on
	NSInteger pageIndex = [self.pages indexOfObject:currentPage];
	
	// Iterate pages backwards
	for (NSInteger p = pageIndex; p >=0; p--) {
		NSMutableArray *page = self.pages[p];

		Line *firstLine = page.firstObject;
		
		// Check if this line is a safe place to start the pagination
		if (!firstLine.unsafeForPageBreak) {
			if (p > 0) {
				NSMutableArray *prevPage = self.pages[p - 1];
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
    self.paperSize = [BeatPaperSizing printableAreaFor:pageSize];
#else
	_paginator.printInfo = [BeatPaperSizing printInfoFor:pageSize];
#endif
}

- (void)setScript:(NSArray *)script {
	// Do preliminary preprocessing
	NSMutableArray *lines = NSMutableArray.array;
	
	for (Line *line in script) {
		if (line == nil || [line isKindOfClass:NSNull.class]) continue; // Plugins can cause havoc sometimes
		else if (line.type == empty || line.omitted) continue;
		
		[lines addObject:line];
	}
	_script = lines;
}

- (void)paginateLines:(NSArray*)lines {
	@synchronized (self) {
		self.script = lines;
		[self paginateFromIndex:0];
	}
}

/*
- (void)paginate {
	@synchronized (self) {
		self.pages = NSMutableArray.new;
		[self paginateFromIndex:0];
	}
}
 */

- (void)useCachedPaginationFrom:(NSInteger)pageIndex {
	// Ignore the last page if it's empty
	if (self.pages.lastObject.count == 0) {
		[self.pages removeLastObject];
		[self.pageBreaks removeLastObject];
	}
    
    // This shouldn't happen, but let's guard the code against weirdness.
    
    if (pageIndex >= self.pageCache.count || self.pageCache.count == 0) {
        NSLog(@"Skipping. Page cache count: %lu", self.pageCache.count);
        return;
    }
    
    @try {
        // Make sure the range doesn't go out of range for some weird reason
        NSRange subRange = NSMakeRange(pageIndex, _pageCache.count - pageIndex);
        if (NSMaxRange(subRange) > _pageCache.count) {
            subRange.length = NSIntersectionRange(subRange, NSMakeRange(0, _pageCache.count)).length;
        }
        
        NSArray *cachedPages = [self.pageCache subarrayWithRange:subRange];
        [self.pages addObjectsFromArray:cachedPages];
        
        // Make sure the range doesn't go out of range for some weird reason
        NSRange lineBreakRange = NSMakeRange(pageIndex + 1, _pageBreakCache.count - pageIndex - 1);
        if (NSMaxRange(lineBreakRange) > _pageBreakCache.count) {
            lineBreakRange.length = NSIntersectionRange(lineBreakRange, NSMakeRange(0, _pageBreakCache.count)).length;
        }
        
        NSArray *cachedLineBreaks = [self.pageBreakCache subarrayWithRange:lineBreakRange];
        [self.pageBreaks addObjectsFromArray:cachedLineBreaks];
    }
    @catch (NSException* e) {
        NSLog(@"ERROR IN PAGINATION: %@", e);
    }
}

- (void)getPaperSizeFromDocument {
	/**
	 
	 We have separate code for macOS and iOS here. The reason is that NSPrintInfo automatically
	 conforms to the default printer, and you can set the paper size through NSPrintInfo.
	 
	 On iOS, we'll fetch our imaginary printable area, based on export settings and use that as page size.
	 
	 */
#if !TARGET_OS_IOS
	// macOS paper sizing
	
	if (_paginator.document || _paginator.printInfo) {
		BeatPrintInfo *printInfo;
		if (_paginator.document) printInfo = _paginator.document.printInfo.copy;
		else printInfo = _paginator.printInfo.copy;
			
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
	_paperSize = [BeatPaperSizing printableAreaFor:_paginator.paperSize];
#endif
}

#pragma mark - Pagination loop

- (bool)paginateFromIndex:(NSInteger)fromIndex
{ 
	// Reset updated pages
	// _updatedPages = NSMutableIndexSet.new;
	
	self.startTime = NSDate.new;
	
	if (!self.script.count) return true;
	
	if (!_livePagination) {
		// Make the lines know their paginator
		for (Line* line in self.script) line.paginator = self.paginator;
	}
	
	[self getPaperSizeFromDocument];
	
	BeatPage *currentPage = BeatPage.new;
	currentPage.maxHeight = _paperSize.height - 72;
	currentPage.delegate = self;
	
	bool hasStartedANewPage = false;

	// create a tmp array that will hold elements to be added to the pages
	_elementQueue = NSMutableArray.new;
	
	// Walk through the elements array and place them on pages.
	for (NSInteger i = 0; i < self.script.count; i++) { @autoreleasepool {
		if (self.cancelled) {
			// An experiment in canceling background-thread pagination
			return false;
		}
		
		Line *element = self.script[i];
		
		// Skip element if it's not in the specified range for pagination
		if (fromIndex > 0 && NSMaxRange(element.textRange) < fromIndex) continue;
		// ... also if it's empty or non-printed
		else if (element.type == empty || element.isTitlePage) continue;
		
		if ([_elementQueue containsObject:element]) continue;
		else [_elementQueue removeAllObjects];
		
		// Skip invisible elements (unless we are printing notes)
		if (element.type == empty) continue;
		else if (element.isInvisible) {
			if (!(_paginator.printNotes && element.note)) continue;
		}
		
		// If this is the FIRST page, add a break to mark for the end of title page and beginning of document
		if (self.pageBreaks.count == 0 && _livePagination) [self pageBreak:element position:0 type:@"First page"];
		
		// If we've started a new page since we began paginating, see if the rest of the page is intact.
		// If so, we can just use our cached results.
		if (_livePagination && hasStartedANewPage && currentPage.count == 0 &&
			!element.unsafeForPageBreak && _pageCache.count > self.pages.count &&
			element.position > self.location) {
			Line *firstLineOnCachedPage = _pageCache[self.pages.count].firstObject;
			
			if (firstLineOnCachedPage.uuid == element.uuid) {
				[self useCachedPaginationFrom:self.pages.count];
				// Stop pagination
				break;
			}
		}
		
		// Reset Y if the page is empty.
		if (currentPage.count == 0) hasStartedANewPage = YES;
		
		// catch forced page breaks first
		if (element.type == pageBreak) {
			[self resetPage:currentPage onCurrentPage:@[element] onNextPage:@[]];
			[self pageBreak:element position:-1 type:@"Forced page break"];
			continue;
		}
		
		// Catch wrong parsing.
		// We SHOULD NOT have orphaned dialogue. This can happen with live pagination, though.
		if (element.type == dialogue && element.string.length == 0) continue;
		
		// Get whole block
		NSArray <Line*>*block = [self blockFor:element];
		[self addBlockOnCurrentPage:block currentPage:currentPage];
	} }
	
	// Add the last page
	[self.pages addObject:currentPage.contents];
	
	// Remove last page if it's empty
	NSArray *lastPage = self.pages.lastObject;
	if (lastPage.count == 0) [self.pages removeLastObject];
	
	// Update last page if needed
	// if (!didUseCache) [_updatedPages addIndex:self.pages.count - 1];
	
	// Only for static pagination
	_lastPageHeight = (float)currentPage.y / (float)currentPage.maxHeight;
	
	return true;
}

- (NSArray*)splitParagraph:(Line*)spillerElement currentPage:(BeatPage*)currentPage {
	// Get space left on current page
	NSInteger space = currentPage.maxHeight - currentPage.y - BeatPaginator.lineHeight;

	NSString *str = spillerElement.stripFormatting;
	NSString *retain = @"";

	// Create the layout manager for remaining space calculation
    NSTextStorage* storage;
    NSLayoutManager *lm = [self viewForSizeCalculation:str line:spillerElement storage:&storage];
    NSInteger glyphs = lm.numberOfGlyphs;
    
	// We'll get the number of lines rather than calculating exact size in NSTextField
	__block NSInteger numberOfLines = 0;
	
	// Iterate through line fragments
	__block CGFloat pageBreakPos = 0;
	__block NSInteger length = 0;
    
	[lm enumerateLineFragmentsForGlyphRange:NSMakeRange(0, glyphs) usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		numberOfLines++;
        
		if (numberOfLines < space / BeatPaginator.lineHeight) {
			NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
			length += charRange.length;
			pageBreakPos += usedRect.size.height;
		} else {
			*stop = true;
		}
	}];
    
	retain = [str substringToIndex:length];
	
	NSArray *splitElements = [spillerElement splitAndFormatToFountainAt:retain.length];
	Line *prePageBreak = splitElements[0];
	Line *postPageBreak = splitElements[1];
	
	return @[prePageBreak, postPageBreak, @(pageBreakPos)];
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

- (bool)printNotes {
	return _paginator.printNotes;
}

- (bool)elementExists:(NSInteger)i {
	if (i < self.script.count) return YES; else return NO;
}

- (CGFloat)elementHeight:(Line *)element lineHeight:(CGFloat)lineHeight {
	NSString *string = element.stripFormatting;
	return [BeatPaginator heightForString:string font:_paginator.font maxWidth:[self widthForElement:element] lineHeight:lineHeight];
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
			if (_paginator.settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_A4;
			else cpl = DUAL_DIALOGUE_US;
			break;
		case dualDialogueCharacter:
			if (_paginator.settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_CHARACTER_A4;
			else cpl = DUAL_DIALOGUE_CHARACTER_US;
			break;
		case dualDialogueParenthetical:
			if (_paginator.settings.paperSize == BeatA4) cpl = DUAL_DIALOGUE_PARENTHETICAL_A4;
			else cpl = DUAL_DIALOGUE_US;
			break;
			
		default:
			if (_paginator.settings.paperSize == BeatA4) cpl = ACTION_A4;
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
- (NSLayoutManager*)viewForSizeCalculation:(NSString*)string line:(Line*)element {
    return [self viewForSizeCalculation:string line:element];
}
- (NSLayoutManager*)viewForSizeCalculation:(NSString*)string line:(Line*)element storage:(NSTextStorage**)storage {
	if (_paginator.font == nil) _paginator.font = BeatFonts.sharedFonts.courier;
	
	NSInteger maxWidth = [self widthForElement:element];
	BeatFont *font = _paginator.font;
	
	if (string == nil) string = @"";
    
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
	font = [font fontWithSize:font.pointSize * 0.8];
#endif
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = NSLayoutManager.new;
    *storage = textStorage;

	NSTextContainer *textContainer = NSTextContainer.new;
	[textContainer setSize:CGSizeMake(maxWidth, MAXFLOAT)];

	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0];
    
	return layoutManager;
}


- (void)pageBreak:(Line*)line position:(CGFloat)position type:(NSString*)reason {
	if (!_livePagination) return; // Don't run this for non-live pagination

	NSNumber *value = [NSNumber numberWithFloat:position];

	if (value && line) {
		[self.pageBreaks addObject:@{ @"line": line, @"position": value, @"reason": (reason) ? reason : @"(none)" }];
	}
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
	else if (line.type != heading && line.type != lyrics && line.type != centered) return @[line];
	
	NSMutableArray *block = NSMutableArray.new;
	
	NSInteger i = [self.script indexOfObject:line];
	if (i == self.script.count - 1) return @[line];

	NSInteger l = i + 1;
	[block addObject:line];
	
	LineType expectedType;
	if (line.type == heading) expectedType = action;
	else if (line.type == lyrics) expectedType = lyrics;
	else if (line.type == centered) expectedType = centered;
	else expectedType = action;
		
	while (l < self.script.count) {
		Line *el = self.script[l];

		if (el.type == empty || el.string.length == 0) {
			l++;
			continue;
		}
		
		if (el.type == expectedType) {
			if (el.beginsNewParagraph && (line.type != heading && line.type != shot)) break;
			
			[block addObject:el];
			
			if (line.type == heading) break;
			
			l++;
		}
		else break;
	}
			
	return block;
}

- (CGFloat)heightForBlock:(NSArray*)block {
	return [self heightForBlock:block page:nil];
}

- (CGFloat)heightForBlock:(NSArray<Line*>*)block page:(BeatPage*)currentPage {
	if (block.firstObject.isDialogue || block.firstObject.isDualDialogue) {
		return [self heightForDialogueBlock:block page:currentPage];
	}
	
	CGFloat fullHeight = 0;
	for (Line *line in block) {
		CGFloat spaceBefore = 0;
		
		// TODO: I just don't bother to think about this conditional mess right now. A problem for my future self.
		if (block.firstObject.type == centered || block.firstObject.type == lyrics) {
			if (currentPage.count > 0 && line == block.firstObject && line.beginsNewParagraph) {
				spaceBefore = [self spaceBeforeForLine:line];
			}
		}
		else {
			if (currentPage.count > 0 || line != block.firstObject) {
				spaceBefore = [self spaceBeforeForLine:line];
			}
		}
                
		CGFloat elementWidth = [self widthForElement:line];
		CGFloat height = [BeatPaginator heightForString:line.stripFormatting font:_paginator.font maxWidth:elementWidth lineHeight:BeatPaginator.lineHeight];
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
		
		NSInteger height = [self elementHeight:line lineHeight:BeatPaginator.lineHeight];
		line.heightInPaginator = height;
		
		dialogueBlockHeight += height;
	}
		
	// Set the height to be the longer one
	if (previousDialogueBlockHeight > dialogueBlockHeight) dialogueBlockHeight = previousDialogueBlockHeight;
	
	if (currentPage.count > 0) {
		dialogueBlockHeight += [self spaceBeforeForLine:block.firstObject];
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
		NSInteger h = [self elementHeight:line lineHeight:BeatPaginator.lineHeight];
		
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

	Line *pageBreakItem;
	NSUInteger suggestedPageBreak = 0;
		
	NSUInteger index = [dialogueBlock indexOfObject:spiller];
	CGFloat remainingSpace = page.remainingSpace; // Make space for (MORE) etc.
	
	// If it doesn't fit, move the whole block on next apge
	if (remainingSpace < BeatPaginator.lineHeight) {
		return @{
			@"page break item": block.firstObject,
			@"position": @(0),
			@"retained": @[],
			@"next page": block
		};;
	}
	
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
        if (prevElement.isAnyParenthetical && tmpThisPage.count == 0) {
            splitAt -= 2;
        }
		
		// Split the block
		[onThisPage addObjectsFromArray:
			 [block subarrayWithRange:NSMakeRange(0, splitAt)]
		];
		[onThisPage addObjectsFromArray:tmpThisPage];
        if (onThisPage.count > 0) [onThisPage addObject:[_paginator moreLineFor:spiller]];
	}
			
	// Add stuff on next page if needed
	if (onThisPage.count) [onNextPage addObject:[_paginator contdLineFor:dialogueBlock.firstObject]];
	[onNextPage addObjectsFromArray:tmpNextPage];
	NSRange splitRange = NSMakeRange(splitAt, dialogueBlock.count - splitAt);
	if (splitRange.length > 0) [onNextPage addObjectsFromArray:[dialogueBlock subarrayWithRange:splitRange]];
	
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

/// Returns an array with [retainedText, splitText]
- (NSArray*)splitDialogueLine:(Line*)line remainingSpace:(CGFloat)remainingSpace pageBreakPosition:(NSUInteger*)suggestedPageBreak
{
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
        CGFloat h = [self elementHeight:tempElement lineHeight:BeatPaginator.lineHeight];
		
		if (h > remainingSpace && !forceNextpage) {
			// If there is space left for less than a single line, avoid trying to squeeze stuff in,
			// and let it flow onto the next page.
			breakPosition = h;
			remainingSpace -= BeatPaginator.lineHeight;
			
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

#pragma mark - Adding items

/**
 This is a generic method for adding items on the current page. This can be done independent of
 the original loop, so that we are able to queue any amount of stuff (including temporary items etc.)
 to be added on pages.
 */
- (void)addBlockOnCurrentPage:(NSArray<Line*>*)block currentPage:(BeatPage*)currentPage {
    [self addBlockOnCurrentPage:block currentPage:currentPage force:false];
}
- (void)addBlockOnCurrentPage:(NSArray<Line*>*)block currentPage:(BeatPage*)currentPage force:(bool)force {
	// Do nothing if the thread is killed
	if (self.cancelled) return;

    if (self.livePagination && fabs([self.startTime timeIntervalSinceNow]) > 8.0) {
        NSLog(@"Pagination timed out.");
        self.cancelled = true;
        return;
    }
	
	Line *element = block.firstObject;
	CGFloat lineHeight = BeatPaginator.lineHeight;
	
	// Calculate block height
	CGFloat fullHeight = [self heightForBlock:block page:currentPage];
	if (fullHeight <= 0.0) return; // Ignore this block if it's empty
	    
	Line *f = block.firstObject;
	NSString *snip = f.string;
	if (f.string.length > 100) snip = [f.string substringToIndex:100];
	
	// Add whole block into temporary element queue
	[_elementQueue addObjectsFromArray:block];

	// Fix to get styling to show up in PDFs. I have no idea.
	// (wtf is this, wondering in 2022. Might originate from the original Fountain repo)
	// if (![element.string isMatch:RX(@" $")]) element.string = [NSString stringWithFormat:@"%@%@", element.string, @""];
	
	// This block fits on page
	if (currentPage.y + fullHeight <= currentPage.maxHeight) {
		[currentPage addBlock:block height:fullHeight];
	}
	// Block doesn't fit
	else {
		CGFloat overflow = currentPage.maxHeight - (currentPage.y + fullHeight);

		// If it fits, just squeeze it on this page
		if (fabs(overflow) <= BeatPaginator.lineHeight * 1.05) {
			[self resetPage:currentPage onCurrentPage:block onNextPage:@[]];
			[self pageBreak:block.lastObject position:-1 type:@"Squeezed"];
			return;
		}
		
		// Find out the spiller (by default it is the last element)
		Line *spillerElement = block.lastObject;
		
		#pragma mark Split scene headings & paragraphs
		// BTW, a much more sensible approach would be to just add scene headings as-is and then
		// drag them on next page if a block was moved in its entirety on the next page.
		// This would fix so many things.

		if (element.type == heading || element.type == action) {
			// Push to next page if it the split would be only 1 line or something
			if ((element.type == heading && fullHeight - fabs(overflow) < lineHeight * 4.5 && fabs(overflow) >= BeatPaginator.lineHeight) ||
				(fullHeight - fabs(overflow) < lineHeight * 2 && fabs(overflow) < BeatPaginator.lineHeight * 2)) {
				[self resetPage:currentPage onCurrentPage:@[] onNextPage:block];
				[self pageBreak:element position:0 type:@"Move the beginning of scene on next page"];
				return;
			}
			
			NSInteger space = currentPage.maxHeight - currentPage.y;
			if (fabs(overflow) > lineHeight && space > lineHeight * 2) {
				// See if we can split stuff across pages
				NSArray *splitElements = [self splitParagraph:spillerElement currentPage:currentPage];
                
				Line *prePageBreak = splitElements[0];
				Line *postPageBreak = splitElements[1];
				CGFloat breakPosition = ((NSNumber*)splitElements[2]).floatValue;
				
				// If it's a heading we need special rules
				if (element.type == heading) {
					// We had something remain on the original page
					if (prePageBreak.string.length) {
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
					NSString *reason = [NSString stringWithFormat:@"Split action  -—  %f overflow  /  %lu left", fabs(overflow), space];
					[self pageBreak:spillerElement position:breakPosition type:reason];
				}
			} else {
				// Reset page and go on
				[self resetPage:currentPage onCurrentPage:@[] onNextPage:block];
				// Add page break info (for live pagination if in use)
				[self pageBreak:element position:0 type:@"Action/Heading did not fit"];
			}
			
			return;
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
			
			// Add page break for live pagination
			if (retainedLines.count) [self pageBreak:pageBreakElement position:pageBreakPosition type:@"Dialogue"];
			else [self pageBreak:block.firstObject position:0 type:@"Dialogue moved on next page"];
			
			return;
		} else {
			// Just add on next page
			[self resetPage:currentPage onCurrentPage:@[] onNextPage:block];
            [self pageBreak:block.firstObject position:0 type:@"Did not fit."];
		}
	}
}

#pragma mark - Reset page
 
- (void)resetPage:(BeatPage*)currentPage onCurrentPage:(NSArray*)prevPageItems onNextPage:(NSArray*)nextPageItems {
    // Do nothing if the current thread is cancelled
	if (self.cancelled) return;
    
	// Global page reset
	if (prevPageItems.count) [currentPage addBlock:prevPageItems height:0]; // No need to calculate height for these elements
	[self.pages addObject:currentPage.contents];

	[currentPage clear];
	
	// Let's run the next page block through height calculator, so its line objects get the correct height.
	// NSInteger nextPageHeight = [self heightForBlock:nextPageItems];
	// if (nextPageItems.count) [currentPage addBlock:nextPageItems height:nextPageHeight];
    
	if (nextPageItems.count > 0) {
		[self addBlockOnCurrentPage:nextPageItems currentPage:currentPage];
	}
}

#pragma mark - Forward spaceBeforeForLine from delegate

- (CGFloat)spaceBeforeForLine:(Line*)line {
    return [self.paginator spaceBeforeForLine:line];
}

@end
