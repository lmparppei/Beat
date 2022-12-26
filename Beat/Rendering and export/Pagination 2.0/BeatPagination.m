//
//  BeatPagination.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class paginates the screenplay based on styles provided by the host delegate.
 
 The new pagination code began as an attempt to both replace the old `BeatPaginator`,
 which was originally based on the very old Fountain pagination code and later rewritten from scratch,
 and to directly render the results when needed.
 
 It turned out that iOS and macOS have varying support for different kinds of `NSAttributedString`
 elements, so rendering had to be separated from this class.
 
 However, you can hook up a class which conforms to `BeatRendererDelegate`, to provide
 extra convenience. With a renderer connected to the pagination, you'll be able to request
 a rendered attributed string directly from the results, ie. `.pages[0].attributedString`
 
 "Live pagination" means continuous pagination. This is used for updating the preview and providing
 page numbering to the editor. Page breaks don't have any use in static/export pagination.
 
 This is still a work in progress. Dread lightly.
 
 */

#import "BeatPagination.h"
#import "BeatFonts.h"
#import "Beat-Swift.h"
#import "BeatPaginationBlock.h"
#import "BeatPaginationBlockGroup.h"
#import "BeatPageBreak.h"


@interface BeatPagination() <BeatPageDelegate>
@property (nonatomic) NSArray<Line*>* lines;

@property (nonatomic) NSMutableArray<Line*>* lineQueue;
@property (nonatomic) BeatFonts* fonts;
@property (nonatomic) RenderStyles* styles;
@property (nonatomic) NSInteger location;

@property (nonatomic) NSMutableDictionary<NSNumber*, NSDictionary*>* lineTypeAttributes;

@property (nonatomic) bool livePagination;

@property (weak, nonatomic) id<BeatPaginationDelegate> delegate;
@property (nonatomic) BeatPaginationPage* currentPage;

@property (nonatomic) NSArray<BeatPaginationPage*>* _Nullable cachedPages;
@end

@implementation BeatPagination

+ (CGFloat) lineHeight { return 12.0; }

+ (BeatPagination*)newPaginationWithLines:(NSArray<Line*>*)lines delegate:(id<BeatPaginationDelegate>)delegate
{
	return [BeatPagination.alloc initWithDelegate:delegate lines:lines titlePage:nil settings:delegate.settings livePagination:false changeAt:0 cachedPages:nil];
}

+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages livePagination:(bool)livePagination changeAt:(NSInteger)changeAt 
{
	return [BeatPagination.alloc initWithDelegate:delegate lines:screenplay.lines titlePage:screenplay.titlePageContent settings:delegate.settings livePagination:livePagination changeAt:changeAt cachedPages:cachedPages];
}

- (instancetype)initWithDelegate:(id<BeatPaginationDelegate>)delegate lines:(NSArray<Line*>*)lines titlePage:(NSArray* _Nullable)titlePage settings:(BeatExportSettings*)settings livePagination:(bool)livePagination changeAt:(NSInteger)changeAt cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages
{
	self = [super init];
	
	if (self) {
		_delegate = delegate;
		
		_fonts = BeatFonts.sharedFonts;
		
		_lines = (lines != nil) ? lines : @[];
		_titlePageContent = (titlePage != nil) ? titlePage : @[];
		_cachedPages = cachedPages;
		
		_livePagination = livePagination;
		_location = changeAt;
		_settings = settings;
		_pages = NSMutableArray.new;
		_lineTypeAttributes = NSMutableDictionary.new;
				
		// Possible renderer module. This can be null.
		_renderer = _delegate.renderer;
		
		// Check for custom styles. If not present, use the shared styles.
		if (_settings.styles != nil) _styles = _settings.styles;
		else _styles = RenderStyles.shared;
		
		_startTime = NSDate.new;
	}
	
	return self;
}

#pragma mark - Convenience stuff

/// A method for backwards compatibility with the old pagination code
- (NSInteger)numberOfPages
{
	if (self.pages.count == 0) [self paginate];
	return self.pages.count;
}

- (void)paginationFinished
{
	[self.delegate paginationFinished:self];
}

- (CGFloat)maxPageHeight
{
	NSSize size = [BeatPaperSizing sizeFor:_settings.paperSize];
	RenderStyle* style = _styles.page;
	
	return size.height - style.marginTop - style.marginBottom - BeatPagination.lineHeight * 2;
}

#pragma mark - Running pagination

/// Look up current line from array of lines. We are using UUIDs for matching, so `indexOfObject:` is redundant here.
- (NSInteger)indexOfLine:(Line*)line {
	for (NSInteger i=0; i<self.lines.count; i++) {
		if ([_lines[i].uuid isEqualTo:line.uuid]) return i;
	}
	return NSNotFound;
}

- (void)paginate
{
	NSInteger startIndex = 0;
	
	if (_livePagination) {
		// This returns the index for both page and the line inside that page
		NSArray<NSNumber*>* indexPath = [self findSafePageAndLineForPosition:self.location pages:self.cachedPages];
		
		NSInteger pageIndex = indexPath[0].integerValue;
		NSInteger lineIndex = indexPath[1].integerValue;
		
		if (pageIndex != NSNotFound && lineIndex != NSNotFound && pageIndex < _cachedPages.count && _cachedPages.count > 0) {
			NSArray* sparedPages = [self.cachedPages subarrayWithRange:NSMakeRange(0, pageIndex)];
			[self.pages setArray:sparedPages];
			
			self.currentPage = _cachedPages[pageIndex];
			Line* safeLine = self.currentPage.lines[lineIndex];
			[self.currentPage clearUntil:safeLine];
			
			startIndex = [self indexOfLine:safeLine];
			NSLog(@"starting index: %lu", startIndex);
		}
	}
	
	if (startIndex == 0 || startIndex == NSNotFound) {
		_pages = NSMutableArray.new;
		_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
		startIndex = 0;
	}
	
	self.success = [self paginateFromIndex:startIndex];
	[self paginationFinished];
}

- (void)useCachedPaginationFrom:(NSInteger)pageIndex
{
	NSArray* reusablePages = [self.cachedPages subarrayWithRange:NSMakeRange(pageIndex, self.cachedPages.count - pageIndex)];
	[_pages addObjectsFromArray:reusablePages];
}

- (bool)paginateFromIndex:(NSInteger)index
{
	// Save start time
	_startTime = [NSDate date];
	
	// Reset queue and use cached pagination if applicable
	_lineQueue = [NSMutableArray arrayWithArray:[self.lines subarrayWithRange:NSMakeRange(index, self.lines.count - index)]];
	
	// Store the number of pages so we can tell if we've begun a new page
	NSInteger pageCountAtStart = _pages.count;
	
	while (_lineQueue.count > 0) {
		// Do nothing if this operation is canceled
		if (_canceled) { return false; }
				
		// Get the first object in the queue array until no lines are left
		Line* line = _lineQueue[0];
		
		// Let's see if we can use cached pages here
		if (_pages.count == pageCountAtStart+1 && _currentPage.blocks.count == 0 && _cachedPages.count > self.pages.count) {
			Line* firstLineOnCachedPage = _cachedPages[_pages.count].lines.firstObject;
			
			if ([line.uuid isEqualTo:firstLineOnCachedPage.uuid]) {
				// We can use cached pagination here.
				[self useCachedPaginationFrom:_pages.count];
				return true;
			}
		}
	
		// Catch wrong parsing (just in case)
		if (line.string.length == 0 ||
			line.isTitlePage ||
			(line.isInvisible && !(_settings.printNotes && line.note))) {
			[_lineQueue removeObjectAtIndex:0];
			continue;
		}
				
		// catch forced page breaks first
		if (line.type == pageBreak) {
			[_lineQueue removeObjectAtIndex:0];
			
			BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:-1.0 element:line reason:@"Forced page break"];
			[self addPage:@[line] toQueue:@[] pageBreak:pageBreak];
			continue;
		}
		
		// Add initial page break when needed
		if (self.pages.count == 0 && _currentPage.blocks.count == 0) {
			_currentPage.pageBreak = [BeatPageBreak.alloc initWithY:0 element:line reason:@"Initial page break"];
		}
		
		/**
		 Get the block for current line and add it to temp element queue.
		 A block is something that has to be handled as one when paginating, such as:
		 • a single paragraph or transition
		 • dialogue block, or a dual dialogue block
		 • a heading or a shot, followed by another block
		*/
		@autoreleasepool {
			NSArray *blocks = [self blocksForLineAt:0];
			[self addBlocks:blocks];
		}
	}
	
	[_pages addObject:_currentPage];
	
	return true;
}

/// Creates blocks out of arrays of `Line` objects and adds them onto pages. Also handles breaking the blocks across pages, and adds the overflowing lines to queue.
- (void)addBlocks:(NSArray<NSArray<Line*>*>*)blocks
{
	NSMutableArray<BeatPaginationBlock*>* pageBlocks = NSMutableArray.new;
		
	for (NSArray<Line*>* block in blocks) {
		BeatPaginationBlock *pageBlock = [BeatPaginationBlock withLines:block delegate:self];
		[pageBlocks addObject:pageBlock];
		
		[_lineQueue removeObjectsInRange:NSMakeRange(0, block.count)];
	}
	
	BeatPaginationBlockGroup *group = [BeatPaginationBlockGroup withBlocks:pageBlocks];
	
	if (_currentPage.remainingSpace >= group.height) {
		// Add blocks on current page
		for (BeatPaginationBlock *pageBlock in pageBlocks) {
			[_currentPage addBlock:pageBlock];
		}
		return;
	}
	
	// Nothing fit, let's break it apart
	CGFloat remainingSpace = _currentPage.remainingSpace;
	
	// If remaining space is less than 1 line, just roll on to next page
	if (remainingSpace < BeatPagination.lineHeight) {
		BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:0 element:group.blocks.firstObject.lines.firstObject reason:@"Nothing fit"];
		[self addPage:@[] toQueue:group.lines pageBreak:pageBreak];
	}
	else if (group.blocks.count > 0) {
		NSArray* split = [group breakGroupWithRemainingSpace:remainingSpace];
		[self addPage:split[0] toQueue:split[1] pageBreak:split[2]];
	}
	else {
		BeatPaginationBlock *pageBlock = group.blocks.firstObject;
		NSArray* split = [pageBlock breakBlockWithRemainingSpace:remainingSpace];
		[self addPage:split[0] toQueue:split[1] pageBreak:split[2]];
	}
}


/**
Returns "blocks" for the given line.
- note: A block is usually any paragraph or a full dialogue block, but for the pagination to make sense, some blocks are grouped together.
That's why we are returning `[ [Line], [Line], ... ]`, and converting those blocks into actual screenplay layout blocks later.

The layout blocks (`BeatPageBlock`) won't contain anything else than the rendered block, which can also mean a full dual-dialogue block.
*/
- (NSArray<NSArray<Line*>*>*)blocksForLineAt:(NSInteger)idx
{
	Line* line = self.lineQueue[idx];
	NSMutableArray<Line*>* block = [NSMutableArray arrayWithObject:line];
	
	if (line.isAnyCharacter) {
		return @[[self dialogueBlockForLineAt:idx]];
	}
	else if (line == _lineQueue.lastObject) {
		return @[block];
	}
	else if (line.type != heading && line.type != lyrics && line.type != centered && line.type != shot) {
		return @[block];
	}
	
	NSInteger i = idx + 1;
	Line* nextLine = self.lineQueue[i];
	
	// If next line is a heading, this block ends there
	if (nextLine.type == heading) {
		return @[block];
	}
	
	// Headings and shots swallow up the whole next block
	if (line.type == heading || line.type == shot) {
		NSArray* followingBlocks = [self blocksForLineAt:i];
		NSMutableArray *blocks = [NSMutableArray arrayWithObject:block];
		[blocks addObjectsFromArray:followingBlocks];
		return blocks;
	}
	
	LineType expectedType;
	if (line.type == lyrics || line.type == centered) expectedType = line.type;
	else { expectedType = action; }
	
	//idx += 1
	while (idx < _lineQueue.count) {
		Line* l = _lineQueue[idx];
		idx += 1;
		
		// Skip empty lines, and break when the next line type is not the one we expected
		if (l.type == empty || l.string.length == 0) { continue; }
		if (l.type == expectedType) {
			if (l.beginsNewParagraph) { break; } // centered and lyric elements might begin a new block
			[block addObject:l];
		} else {
			break;
		}
	}
	
	return @[block];
}

/// Returns dialogue block for the given line index
- (NSArray<Line*>*)dialogueBlockForLineAt:(NSInteger)idx
{
	Line *line = _lineQueue[idx];
	NSMutableArray<Line*>* block = NSMutableArray.new;
	[block addObject:line];
	
	bool hasBegunDualDialogue = false;
	
	for (NSInteger i=idx+1; i<_lineQueue.count; i++) {
		Line* l = _lineQueue[i];
		
		if (l.type == character) break;
		else if (!l.isDialogue && !l.isDualDialogue) break;
		else if (l.isDualDialogue) hasBegunDualDialogue = true;
		else if (hasBegunDualDialogue && (l.isDialogue || l.type == dualDialogueCharacter )) break;

		[block addObject:l];
	}
		
	return block;
}

- (void)addPage:(NSArray<Line*>*)elements toQueue:(NSArray<Line*>*)toQueue pageBreak:(BeatPageBreak*)pageBreak
{
	BeatPaginationBlock *block = [BeatPaginationBlock withLines:elements delegate:self];
	[_currentPage addBlock:block];
	[self.pages addObject:_currentPage];
	
	// Add objects to queue
	NSRange range = NSMakeRange(0, toQueue.count);
	NSIndexSet* indices = [NSIndexSet indexSetWithIndexesInRange:range];
	[_lineQueue insertObjects:toQueue atIndexes:indices];
	
	_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
	_currentPage.pageBreak = pageBreak;
}


#pragma mark - Line lookup

/// Returns page index based on line position
- (NSInteger)findPageIndexAt:(NSInteger)position pages:(NSArray<BeatPaginationPage*>*)pages
{
	for (NSInteger i=0; i<pages.count; i++) {
		BeatPaginationPage *page = pages[i];
		NSRange range = page.representedRange;
		// get page.representedRange etc
		
		if (range.location > position) {
			// Return PREVIOUS page (as we've actually passed the position we've been looking for)
			if (i > 0) return i - 1;
			else return 0 ;
		}
	}
	
	return NSNotFound;
}

/// Returns page index for given line
- (NSInteger)findPageIndexForLine:(Line*)line
{
	for (NSInteger i=0; i<self.pages.count; i++) {
		BeatPaginationPage* page = self.pages[i];
		if (NSLocationInRange(line.position, page.representedRange)) {
			return i;
		}
		else if (i > 0 && line.position > NSMaxRange(self.pages[i-1].representedRange)) {
			return i - 1;
		}
	}
	
	return NSNotFound;
}

/// Returns an array with index path to a safe line from the given position in screenplay.
- (NSArray*)findSafePageAndLineForPosition:(NSInteger)position pages:(NSArray<BeatPaginationPage*>*)pages
{
	NSInteger pageIndex = [self findPageIndexAt:position pages:pages];
	if (pageIndex == NSNotFound) return @[ @0, @0 ];
	
	while (pageIndex >= 0) {
		BeatPaginationPage* page = pages[pageIndex];
		
		NSInteger i = [page indexForLineAtPosition:position];
		if (i == NSNotFound) return @[ @0, @0 ];
			
		NSInteger safeIndex = [page findSafeLineFromIndex:i];
		
		// No suitable line found or we ended up on the first line of the page,
		// let's find a suitable line on the previous page.
		if (safeIndex == NSNotFound || safeIndex == 0) {
			pageIndex -= 1;
			continue;
		}
		
		return @[@(pageIndex), @(safeIndex)];
	}
	
	return @[@0, @0];
}

#pragma mark - Heights of scenes

- (CGFloat)heightForScene:(OutlineScene*)scene
{
	NSInteger pageIndex = [self findPageIndexForLine:scene.line];
	if (pageIndex == NSNotFound) return 0.0;
	
	BeatPaginationPage* page = self.pages[pageIndex];
	CGFloat height = 0.0;
	NSInteger numberOfBlocks = 0;
	
	NSInteger blockIndex = [page blockIndexForLine:scene.line];
	
	for (NSInteger i = pageIndex; i < self.pages.count; i++) {
		BeatPaginationPage* page = self.pages[i];
		
		for (NSInteger j = blockIndex; j < page.blocks.count; j++) {
			BeatPaginationBlock* block = page.blocks[j];
			if (block.type != heading) {
				height += block.height;
				if (numberOfBlocks == 0) height -= block.topMargin; // No top margin for first block
				
				numberOfBlocks += 1;
			} else {
				// Next heading block was encountered
				return height;
			}
		}
		blockIndex = 0;
	}
	
	return 0.0;
}

/*
 func heightForScene(_ scene:OutlineScene) -> CGFloat {
	 let pageIndex = page(forScene: scene)
	 
	 // No page found for this scene
	 if (pageIndex < 0) { return 0.0 }
	 
	 let page = pages[pageIndex]
	 var blockIndex = page.blockIndex(for: scene.line)
	 var height = 0.0
	 
	 for i in pageIndex ..< pages.count {
		 let page = pages[i]
		 
		 for j in blockIndex ..< page.blocks.count {
			 let block = page.blocks[j] as! BeatPaginationBlock
			 if block.type != .heading {
				 height += block.height()
			 } else {
				 break
			 }
		 }
		 blockIndex = 0
	 }
	 
	 return height
 }
 */


#pragma mark - CONT'D and (MORE)

/// Returns a `Line` object with character cue followed by `(CONT'D)` extension for continuing dialogue block after a page break.
+ (Line*)contdLineFor:(Line*)line
{
	NSString *extension = BeatPagination.contdString;
	NSString *cue = [line.stripFormatting stringByReplacingOccurrencesOfString:extension withString:@""];
	cue = [cue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	NSString *contdString = [NSString stringWithFormat:@"%@%@", cue, extension];
	Line *contd = [Line.alloc initWithString:contdString type:character];
	contd.position = line.position;
	contd.nextElementIsDualDialogue = line.nextElementIsDualDialogue;
	if (line.type == dualDialogueCharacter) contd.type = dualDialogueCharacter;
	
	return contd;
}

/// Returns a `Line` object for the `(MORE)` at the bottom of a page when a dialogue block is broken across pages.
+ (Line*)moreLineFor:(Line*)line
{
	LineType type = (line.isDualDialogue) ? dualDialogueMore : more;
	Line *more = [Line.alloc initWithString:[BeatPagination moreString] type:type];
	more.position = line.position;
	more.unsafeForPageBreak = YES;
	return more;
}

+ (NSString*)moreString
{
	NSString *moreStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemMore"];
	return [NSString stringWithFormat:@"(%@)", moreStr];
}

+ (NSString*)contdString
{
	NSString *contdStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemContd"];
	return [NSString stringWithFormat:@" (%@)", contdStr]; // Extra space here to be easily able to add this after a cue
}

@end
