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
 page numbering to the editor, while optimizing the process by reusing old results.
 Page breaks don't have any use in static/export pagination.
 
 This is still a work in progress. Dread lightly.
 
 */

#import <TargetConditionals.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatParsing/BeatParsing.h>

#import "BeatPagination.h"

#import "BeatPaginationBlock.h"
#import "BeatPaginationBlockGroup.h"
#import "BeatPageBreak.h"

#if TARGET_OS_IOS
#define BequalTo isEqual
#else
#define BequalTo isEqualTo
#endif


@interface BeatPagination() <BeatPageDelegate>
@property (nonatomic) NSArray<Line*>* lines;

/// Fonts used for exporting
@property (nonatomic) BeatFontSet* fonts;

/// The position where last change was made. Used only for live pagination.
@property (nonatomic) NSRange changedRange;

/// Stored paragraph attributes for different line types. Used to calculate paragraph heights.
@property (nonatomic) NSMutableDictionary<NSNumber*, NSDictionary*>* lineTypeAttributes;

/// Set `true` when paginating editor content.
@property (nonatomic) bool livePagination;

/// `BeatPaginationDelegate` is called when pagination operation finishes.
@property (weak, nonatomic) id<BeatPaginationDelegate> delegate;

/// The currently "open" page which accepts new elements.
@property (nonatomic) BeatPaginationPage* currentPage;

/// The upcoming lines to be paginated. Parsed lines are separated into blocks, and inserted to this array.
@property (nonatomic) NSMutableArray<Line*>* lineQueue;

/// Reusable pages from the previous pagination operation.
@property (nonatomic) NSArray<BeatPaginationPage*>* _Nullable cachedPages;

/// UUID -> line table
//@property (nonatomic) NSMutableDictionary* UUIDsToLines;
@property (nonatomic) NSMapTable* UUIDsToLines;

/// Reusable styles for paragraph sizing
@property (nonatomic) NSMutableDictionary<NSString*, NSParagraphStyle*>* paragraphStyles;///

@property (nonatomic) bool timedOut;

@end

@implementation BeatPagination

/// Returns the default line height
+ (CGFloat) lineHeight { return 12.0; }

+ (BeatPagination*)newPaginationWithLines:(NSArray<Line*>*)lines delegate:(__weak id<BeatPaginationDelegate>)delegate
{
    return [BeatPagination.alloc initWithDelegate:delegate lines:lines titlePage:nil settings:delegate.settings livePagination:false changedRange:NSMakeRange(0,0) cachedPages:nil];
}

+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(__weak id<BeatPaginationDelegate>)delegate cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages livePagination:(bool)livePagination changedRange:(NSRange)changedRange
{
	return [BeatPagination.alloc initWithDelegate:delegate lines:screenplay.lines titlePage:screenplay.titlePageContent settings:delegate.settings livePagination:livePagination changedRange:changedRange cachedPages:cachedPages];
}

- (instancetype)initWithDelegate:(__weak id<BeatPaginationDelegate>)delegate lines:(NSArray<Line*>*)lines titlePage:(NSArray* _Nullable)titlePage settings:(BeatExportSettings*)settings livePagination:(bool)livePagination changedRange:(NSRange)changedRange cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages
{
	self = [super init];
	
	if (self) {
		_delegate = delegate;
        
		_lines = (lines != nil) ? lines : @[];
		_titlePageContent = (titlePage != nil) ? titlePage : @[];
		
		// Transfer ownership of cached pages
        if (cachedPages.count) {
            NSMutableArray* copiedPages = [NSMutableArray arrayWithCapacity:cachedPages.count];
            for (BeatPaginationPage* page in cachedPages) {
                BeatPaginationPage* copiedPage = [page copyWithDelegate:self];
                [copiedPages addObject:copiedPage];
            }
            _cachedPages = copiedPages;
        }
		
		_livePagination = livePagination;
        _changedRange = changedRange;
		_settings = settings;
		_pages = NSMutableArray.new;
		_lineTypeAttributes = NSMutableDictionary.new;
        
		// Possible renderer module. This can be null.
		_renderer = _delegate.renderer;
        
        // Set up fonts
        BeatStylesheet* stylesheet = settings.styles;
        _fonts = [BeatFontManager.shared fontsFor:stylesheet.page.fontType]; // defaults to 0, which is fixed
				
		_startTime = NSDate.new;
	}
	
	return self;
}

/// Returns either the shared render styles or custom styles included in export settings (if available)
- (BeatStylesheet*)styles {
	if (_settings.styles != nil) return _settings.styles;
	else return BeatStyles.shared.defaultStyles;
}


#pragma mark - Delivering results

/// Called when this operation is finished.
- (void)paginationFinished
{
    _running = false;

    // Update page numbers. If the style enforces a pagination mode, we'll use that instead of the document setting.
    BeatPageNumberingMode mode = (self.styles.document.paginationMode != -1) ? self.styles.document.paginationMode : [self.settings.documentSettings getInt:DocSettingPageNumberingMode];
    
    NSInteger pageNumber = self.settings.firstPageNumber;
    bool numberingBegan = (mode == BeatPageNumberingModeDefault);
    
    for (BeatPaginationPage* page in self.pages) {
        if (!numberingBegan) {
            if (mode == BeatPageNumberingModeFirstScene && page.hasScene) {
                // This page will get a number, because it has a scene
                numberingBegan = true;
            } else if (mode == BeatPageNumberingModeFirstPageBreak && page.hasForcedPageBreak) {
                // This page WON'T get a number, but the following ones do
                numberingBegan = true;
                continue;
            }
        }
        
        if (numberingBegan && page.customPageNumber == nil) {
            page.pageNumber = pageNumber;
            pageNumber += 1;
        }
    }
    
    [self.delegate paginationFinished:self];
}

- (NSDictionary<NSValue*,NSArray<NSNumber*>*>*)editorPageBreaks
{
    // This is *not* a live pagination, so let's just return zero
    if (self.delegate.editorDelegate == nil) {
        NSLog(@"Warning: nil delegate when trying to create editor page breaks");
        return @{};
    }
    NSInteger textLength = self.delegate.editorDelegate.text.length;
    
    NSMutableDictionary<NSValue*,NSArray<NSNumber*>*>* pageBreaks = NSMutableDictionary.new;
    
    //NSInteger pageNumber = 0;
    
    for (BeatPaginationPage* page in self.pages) {
        BeatPageBreak* pageBreak = page.pageBreak;
        NSInteger position = pageBreak.element.position + pageBreak.index;
        
        // If the page break happens at *end* of the block, we'll display the marker after line break
        if (pageBreak.index == -1 || pageBreak.index == pageBreak.element.length) {
            position = pageBreak.element.position + pageBreak.element.length + 1;
        }
        // Don't go out of range
        if (position > textLength) position = textLength;
        
        // Store the local position of character
        NSUInteger localIndex = position - pageBreak.element.position;
        NSValue* key = [NSValue valueWithNonretainedObject:pageBreak.element];
                
        pageBreaks[key] = @[page.pageNumberForPrinting, @(localIndex)];
    }
    
    return pageBreaks;
}

/// Returns actual page breaks. Do NOT retain this array, because it might lead to retain cycles.
- (NSArray<BeatPageBreak*>*)pageBreaks
{
    NSMutableArray<BeatPageBreak*>* pageBreaks = NSMutableArray.new;
    
    for (BeatPaginationPage* page in self.pages) {
        if (page.pageBreak != nil) [pageBreaks addObject:page.pageBreak];
    }
    
    return pageBreaks;
}

#pragma mark - Convenience stuff

/// A method for backwards compatibility with the old pagination code. Begins pagination if it hasn't run yet.
- (NSInteger)numberOfPages
{
	if (self.pages.count == 0) [self paginate];
	return self.pages.count;
}


/// Returns max height for content in this current pagination context.
- (CGFloat)maxPageHeight
{
    RenderStyle* style = self.styles.page;
    if (_settings == nil) _settings = self.delegate.settings;
    
    CGFloat lineHeight = (style.lineHeight > 0) ? style.lineHeight : BeatPagination.lineHeight;
    CGSize size = [BeatPaperSizing sizeFor:_settings.paperSize];
    CGFloat headerHeight = lineHeight * 3;
    
    // Additional margin for paper size
    CGFloat additionalMargin = (_settings.paperSize == BeatA4) ? style.marginBottomA4 : style.marginBottomLetter;
    
	return size.height - style.marginTop - style.marginBottom - headerHeight - additionalMargin;
}

#pragma mark - Actual pagination

/// Look up current line from array of lines. We are using UUIDs for matching, so `indexOfObject:` can't be used here.
- (NSInteger)indexOfLine:(Line*)line {
	for (NSInteger i=0; i<self.lines.count; i++) {
        if ([_lines[i].uuid uuidEqualTo:line.uuid]) return i;
	}
	return NSNotFound;
}

- (void)paginate
{
	NSInteger startIndex = 0;
    _running = true;
	
    /**
        For live pagination, we'll check if we can reuse some of the earlier pages.
        A safe page is one page before where the actual edit was made, because some content might have been rolled on to next page, and editing anything on current page might change this.
     */
	if (_livePagination && self.cachedPages.count > 0) {
		NSArray<NSNumber*>* indexPath = [self findSafePageAndLineForPosition:self.changedRange.location pages:self.cachedPages];
		
		NSInteger pageIndex = indexPath[0].integerValue;
		NSInteger lineIndex = indexPath[1].integerValue;
				
        // If both a safe page and a suitable line on it was found, we'll reuse pages until that line.
		if (pageIndex != NSNotFound && lineIndex != NSNotFound && pageIndex < _cachedPages.count && pageIndex >= 0 && lineIndex >= 0) {
            // Reuse pages until index
			NSArray* sparedPages = [self.cachedPages subarrayWithRange:NSMakeRange(0, pageIndex)];
			[self.pages setArray:sparedPages];
			
            // If any pages were stored, get current page from cached epages.
			if (self.pages.count > 0) {
				self.currentPage = _cachedPages[pageIndex];
				
                // Clear current page until given index
				if (self.currentPage.lines.count > 0 && lineIndex != NSNotFound) {
					Line* safeLine = self.currentPage.lines[lineIndex];
					[self.currentPage clearUntil:safeLine];
					
					startIndex = [self indexOfLine:safeLine];
				} else {
					startIndex = 0;
				}
			} else {
				startIndex = 0;
			}
		}
	}
	
    // If we are starting from beginning, let's just scrap everything and begin from a clean slate.
	if (startIndex == 0 || startIndex == NSNotFound) {
		_pages = NSMutableArray.new;
		_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
		startIndex = 0;
	}
    
    // Paginate and call delegate method when finished.
	self.success = [self paginateFromIndex:startIndex];
	[self paginationFinished];
}

/// Use old pagination results starting from given index.
- (void)useCachedPaginationFrom:(NSInteger)pageIndex
{
	NSArray* reusablePages = [self.cachedPages subarrayWithRange:NSMakeRange(pageIndex, self.cachedPages.count - pageIndex)];
	[_pages addObjectsFromArray:reusablePages];
}

/// Begin pagination from given line index
- (bool)paginateFromIndex:(NSInteger)index
{
	// Save start time
    _startTime = NSDate.date;
	
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
		if (_pages.count == pageCountAtStart+2 && _currentPage.blocks.count == 0 && _cachedPages.count > self.pages.count && line.position > NSMaxRange(_changedRange)) {
			Line* firstLineOnCachedPage = _cachedPages[_pages.count].lines.firstObject;

			if ([line.uuid uuidEqualTo:firstLineOnCachedPage.uuid]) {
				// We can use cached pagination here.
				[self useCachedPaginationFrom:_pages.count];
				return true;
			}
		}
			
		// Catch wrong parsing (just as a precaution)
		if (line.string.length == 0 ||
			line.type == empty ||
			line.isTitlePage ||
			(line.isOmitted) ||
            (line.isNote && !_settings.printNotes) ||

            // Check if the line is invisible AND it's not spared in export settings.
            (line.isInvisible &&
                !([_settings.additionalTypes containsIndex:line.type] || (line.isNote && _settings.printNotes))
             )
            ) {
			[_lineQueue removeObjectAtIndex:0];
			continue;
		}
				
		// catch forced page breaks first
		if (line.type == pageBreak) {
			[_lineQueue removeObjectAtIndex:0];
			
            BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:-1 element:line attributedString:nil reason:@"Forced page break"];
			[self addPage:@[line] toQueue:@[] pageBreak:pageBreak];
			continue;
		}
        
        // Then catch elements which might have page break style
        RenderStyle* style = [self.styles forLine:line];
        if (style.beginsPage && _currentPage.blocks.count > 0) {
            BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:line attributedString:nil reason:@"Element begins page"];
            [self addPage:@[] toQueue:@[] pageBreak:pageBreak];
        }
		
		// Add initial page break when needed
		if (self.pages.count == 0 && _currentPage.blocks.count == 0) {
			//_currentPage.pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:line lineHeight:self.styles.page.lineHeight reason:@"Initial page break"];
            _currentPage.pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:line attributedString:nil reason:@"Initial page break"];
		}
		
		/**
		 Get the block for current line and add it to temp element queue.
		 A block is something that has to be handled as one when paginating, such as:
		 • a single paragraph or transition
		 • dialogue block, or a dual dialogue block
		 • a heading or a shot, followed by another block
		*/
		@autoreleasepool {
            if (_canceled) return false;
			NSArray *blocks = [self blocksForLineAt:0];
			[self addBlocks:blocks];
		}
	}
	
    if (_currentPage.blocks.count > 0) {
        [self addPage:@[] toQueue:@[] pageBreak:nil];
        //[_pages addObject:_currentPage];
    }
	
	return true;
}

- (NSArray<Line*>*)applyPaginationRulesToBlock:(NSArray<Line*>*)block previous:(Line*)prevLine
{
    Line* previousLine = prevLine;
    NSMutableArray<Line*>* processedBlock = [NSMutableArray arrayWithCapacity:block.count];
    
    for (Line* line in block) {
        if ([self.styles shouldInclude:line.type after:previousLine.type]) {
            [processedBlock addObject:line];
            previousLine = line;
        }
    }
    
    return processedBlock;
}

/// Creates blocks out of arrays of `Line` objects and adds them onto pages. Also handles breaking the blocks across pages, and adds the overflowing lines to queue.
- (void)addBlocks:(NSArray<NSArray<Line*>*>*)blocks
{
	// Do nothing. This can happen with live pagination.
    if (blocks.count == 0 || _canceled) return;
    
    // Avoid infinite loops here
    if ([NSDate.new timeIntervalSinceDate:_startTime] > 5.0) {
        NSLog(@"WARNING: Pagination timed out (%f)", [NSDate.new timeIntervalSinceDate:_startTime]);
        self.timedOut = true;
        self.canceled = true;
        return;
    }
    
    // Array for possible blocks
    NSMutableArray<BeatPaginationBlock*>* pageBlocks = NSMutableArray.new;
    
    NSArray<Line*>* previousBlock;
    
	for (NSArray<Line*>* block in blocks) {
		if (block.count == 0) continue;
        
        // if we have pagination rules, let's apply them here
        NSArray<Line*>* aBlock = (self.styles.hasPaginationRules) ? [self applyPaginationRulesToBlock:block previous:previousBlock.lastObject] : block;
        
        // create a block for pagination
        if (aBlock.count > 0) {
            BeatPaginationBlock *pageBlock = [BeatPaginationBlock withLines:aBlock delegate:self];
            [pageBlocks addObject:pageBlock];
            previousBlock = block;
        }
        
        [_lineQueue removeObjectsInRange:NSMakeRange(0, block.count)];
	}
	
	if (pageBlocks.count == 0) return;
	
	BeatPaginationBlockGroup *group = [BeatPaginationBlockGroup withBlocks:pageBlocks delegate:self];
    CGFloat lineHeight = (self.styles.page.lineHeight >= 0) ? self.styles.page.lineHeight : BeatPagination.lineHeight;
    
    // Add a safety margin to remaining sapce so we won't cut off stuff when it's like 2 points over max height
	if (_currentPage.remainingSpace + lineHeight * 0.2 >= group.height) {
		// Add blocks on current page
		for (BeatPaginationBlock *pageBlock in pageBlocks) {
			[_currentPage addBlock:pageBlock];
		}
		return;
	}
    
	// Nothing fit, let's break it apart
	CGFloat remainingSpace = _currentPage.remainingSpace;
    
	// If remaining space is less than 1 line OR we're just leaving one line on this page, just roll on to next page
	if (remainingSpace < lineHeight || (remainingSpace <= lineHeight + group.topMargin)
        ) {
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:group.blocks.firstObject.lines.firstObject attributedString:nil reason:@"Nothing fit"];
		[self addPage:@[] toQueue:group.lines pageBreak:pageBreak];
	} else if (group.blocks.count > 0) {
        // Break the block group
		NSArray* split = [group breakGroupWithRemainingSpace:remainingSpace styles:self.styles];
		[self addPage:split[0] toQueue:split[1] pageBreak:split[2]];
	} else {
        // Just break a single block
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
    
    // Some lines might produce new items, which means we'll replace that line with the new components
    if (line.resolvedMacros.count > 0) {
        NSArray* components = [self getProducedLinesFor:line];
        
        if (components.count > 0) {
            [self.lineQueue removeObjectAtIndex:idx];
            [self.lineQueue insertObjects:components atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(idx, components.count)]];
            line = self.lineQueue[idx];
        }
    }
    
	NSMutableArray<Line*>* block = [NSMutableArray arrayWithObject:line];
	
	if (line.isAnyCharacter) {
		return @[[self dialogueBlockForLineAt:idx]];
	}
	else if (line == _lineQueue.lastObject) {
		return @[block];
	}
	else if (line.type != heading &&
             line.type != lyrics &&
             line.type != centered &&
             line.type != shot &&
             line.type != section) {
		return @[block];
	}
	
	NSInteger i = idx + 1;
	Line* nextLine = self.lineQueue[i];
	
	// If next line is a heading or a line break AND we didn't just begin a higher-level block, this one ends here
	if (((nextLine.type == heading || nextLine.type == pageBreak) && line.type != section) || (line.type == section && nextLine.type == section)) {
		return @[block];
	}
	
	// Headings, shots and sections swallow up the whole next block.
    // Note that this COULD lead to a silly recursive loop, but let's hope it doesn't.
	if (line.type == heading || line.type == shot || line.type == section) {
		NSArray* followingBlocks = [self blocksForLineAt:i];
		NSMutableArray *blocks = [NSMutableArray arrayWithObject:block];
		[blocks addObjectsFromArray:followingBlocks];
		return blocks;
	}
	
	LineType expectedType;
	if (line.type == lyrics || line.type == centered) expectedType = line.type;
	else { expectedType = action; }
	
	while (i < _lineQueue.count) {
		Line* l = _lineQueue[i];
		i += 1;
		
		// Skip empty lines, and break when the next line type is not the one we expected
        if (l.type == empty || l.string.length == 0) {
            continue;
        } else if (l.type == expectedType) {
            // centered and lyric elements might begin a new block
            if (l.beginsNewParagraph) {
                break;
            }
            
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
        //if (l.type == character || (l.type == dualDialogueCharacter && hasBegunDualDialogue)) break;
		else if (!l.isDialogue && !l.isDualDialogue) break;
		else if (l.isDualDialogue) hasBegunDualDialogue = true;
		else if (hasBegunDualDialogue && (l.isDialogue || l.type == dualDialogueCharacter )) break;

		[block addObject:l];
	}
		
	return block;
}

- (void)addPage:(NSArray<Line*>*)elements toQueue:(NSArray<Line*>*)toQueue pageBreak:(BeatPageBreak*)pageBreak
{
    if (_canceled) return;
    
    if (elements.count > 0) {
        BeatPaginationBlock *block = [BeatPaginationBlock withLines:elements delegate:self];
        [_currentPage addBlock:block];
    }
    
	[self.pages addObject:_currentPage];
	
	// Add objects to queue
	NSRange range = NSMakeRange(0, toQueue.count);
	NSIndexSet* indices = [NSIndexSet indexSetWithIndexesInRange:range];
	[_lineQueue insertObjects:toQueue atIndexes:indices];
	
    if (pageBreak != nil) {
        _currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
        _currentPage.pageBreak = pageBreak;
    }
}


#pragma mark - Line lookup

- (NSInteger)pageIndexForScene:(OutlineScene*)scene
{
    return [self findPageIndexForLine:scene.line];
}

- (NSInteger)pageNumberForScene:(OutlineScene*)scene
{
    return [self pageNumberAt:scene.position];
}


- (NSInteger)pageNumberAt:(NSInteger)location
{
    NSInteger p = [self findPageIndexAt:location];
    if (p == NSNotFound) return 0;
    else return p + 1; // We'll use human-readable page numbers here, not an index
}

/// Returns page index based on line position
- (NSInteger)findPageIndexAt:(NSInteger)position pages:(NSArray<BeatPaginationPage*>*)pages
{
    return [self findPageIndexInRange:NSMakeRange(position, 0) pages:pages];
}

NSMutableDictionary<NSValue*,NSNumber*>* safeRanges;
- (NSInteger)findPageIndexInRange:(NSRange)lineRange pages:(NSArray<BeatPaginationPage*>*)pages
{
    // A hacky fix for a weird bug which only happens in novel mode. No idea.
    // if (pages.count == 1) return 0;
    
    NSMapTable* uuids = self.uuids;
    
    NSInteger idx = NSNotFound;
    NSRange range = NSMakeRange(NSNotFound, 0);
    
	for (NSInteger i=0; i<pages.count; i++) {
		BeatPaginationPage *page = pages[i];
		range = [page safeRangeWithUUIDs:uuids];
		
        // Location is inside this page range
        if (NSLocationInRange(lineRange.location, range) || NSLocationInRange(NSMaxRange(lineRange), range) ) {
            idx = i;
            break;
        }
		
        // We've gone past the original location, return the previous page (or the first, if something went wrong)
		else if (range.location > lineRange.location) {
			idx = (i > 0) ? i - 1 : 0;
            break;
		}
	}
    
    return idx;
}

- (NSInteger)findPageIndexAt:(NSInteger)position
{
    return [self findPageIndexAt:position pages:self.pages];
}

/// Returns page index for given line
- (NSInteger)findPageIndexForLine:(Line*)line
{
	for (NSInteger i=0; i<self.pages.count; i++) {
		BeatPaginationPage* page = self.pages[i];
		if (NSLocationInRange(line.position, page.representedRange)) {
			return i;
		}
		else if (i > 0 && line.position < self.pages[i].representedRange.location) {
			return i - 1;
		}
	}
	
	return NSNotFound;
}

/// Returns an array with index path to a safe line from the given position in screenplay.
- (NSArray*)findSafePageAndLineForPosition:(NSInteger)position pages:(NSArray<BeatPaginationPage*>*)pages
{
	if (pages.count == 0) return @[ @0, @0 ];
	
	NSInteger pageIndex = [self findPageIndexAt:position pages:pages];
	if (pageIndex == NSNotFound || pageIndex < 0) return @[ @0, @0 ];
	
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

- (NSMapTable<NSUUID*, Line*>*)uuids
{
    // Get actual lines for live pagination, and only the paginated ones for static pagination.
    if (self.delegate.editorDelegate != nil) {
        return self.delegate.editorDelegate.parser.uuidsToLines;
    }
    
    if (_UUIDsToLines != nil) return _UUIDsToLines;
    
    NSMapTable* uuids = NSMapTable.strongToWeakObjectsMapTable;
    for (Line* line in self.lines) {
        [uuids setObject:line forKey:line.uuid.copy];
    }
    
    _UUIDsToLines = uuids;
    return _UUIDsToLines;
}

#pragma mark - Heights of scenes

/// Find line based on UUID
- (NSInteger)indexForEditorLine:(Line*)line {
    NSInteger idx = NSNotFound;
    for (NSInteger i=0; i<_lines.count; i++) {
        if ([_lines[i].uuid BequalTo:line.uuid]) {
            idx = i;
            break;
        }
    }
    
    return idx;
}

- (CGFloat)heightForScene:(OutlineScene*)scene {
    // Height for omitted scenes is always 0.0
    if (scene.omitted) return 0.0;
    
    
    // We can't use scene.range here, because it ends where an omitted scene might begin.
    // Let's find the next scene, then.
    NSInteger lineIndex = [self indexForEditorLine:scene.line];
    NSInteger endIndex = 0;
    
    if (lineIndex == NSNotFound) return 0.0;
    
    // Find next scene heading
    for (NSInteger i=lineIndex+1; i<_lines.count; i++) {
        Line* line = _lines[i];
        if (line.type == heading && !line.omitted) {
            endIndex = i - 1;
            break;
        }
        else if (line == _lines.lastObject) {
            endIndex = i;
        }
    }
    
    Line* firstLine = _lines[lineIndex];
    Line* lastLine = _lines[endIndex];
    
    NSRange range = NSMakeRange(firstLine.position, NSMaxRange(lastLine.range) - firstLine.position);
    
    return [self heightForRange:range];
}

- (CGFloat)heightForRange:(NSRange)range
{
    @synchronized (self.pages) {
        NSInteger pageIndex = [self findPageIndexInRange:range pages:self.pages];
        
        if (pageIndex == NSNotFound) {
            NSLog(@"⚠️ heightForRange: Page not found: range %lu, %lu", range.location, range.length);
            return 0.0;
        }
        
        // Find the page + block index.
        // Because we might be looking at reused pages with antiquated ranges, let's try our best to find them.
        
        BeatPaginationPage* page;
        NSInteger blockIndex = NSNotFound;
        
        for (NSInteger i=pageIndex; i<self.pages.count; i++) {
            page = self.pages[pageIndex];
            blockIndex = [page nearestBlockIndexForRange:(NSRange){ range.location, 0 }];
            if (blockIndex != NSNotFound) {
                pageIndex = i;
                break;
            }
        }
        
        if (blockIndex == NSNotFound || page == nil) return 0.0;
        
        bool hasBegunNewPage = false;
        CGFloat height = 0.0;
        CGFloat previousRemainingSpace = 0.0;
        
        for (NSInteger i = pageIndex; i < self.pages.count; i++) {
            BeatPaginationPage* page = self.pages[i];
            // Make sure we have transferred the ownership correctly
            page.delegate = self;
            
            for (NSInteger j = blockIndex; j < page.blocks.count; j++) {
                BeatPaginationBlock* block = page.blocks[j];
                
                Line* firstLine = block.lines.firstObject;
                
                if (firstLine.position < NSMaxRange(range)) {
                    // Check if there was a page break in-between the scene, and add the height to the scene
                    if (hasBegunNewPage) {
                        hasBegunNewPage = false;
                        height += previousRemainingSpace;
                        previousRemainingSpace = 0.0;
                    }
                    
                    if (j == page.blocks.count - 1) {
                        // Last block on page, we'll make a note that this we might need to include remaining space in the height.
                        previousRemainingSpace = page.remainingSpace;
                        hasBegunNewPage = true;
                    }
                    
                    // No height for page break items
                    if (block.type == pageBreak) continue;
                    
                    height += block.height;
                    if (j == 0) height -= block.topMargin; // Remove top margin for first block
                    
                } else {
                    // Out of given range, stop
                    return height;
                }
            }
            blockIndex = 0;
        }
        
        return height;
    }
}


#pragma mark - Paragraph sizing

- (NSParagraphStyle*)paragraphStyleFor:(Line*)line
{
    NSString* lineType = line.typeName;
    
    // If we've already created this style, return it
    if (_paragraphStyles[lineType]) return _paragraphStyles[lineType];
    
    RenderStyle* style = [self.styles forLine:line];
    
    // Create a bare-bones paragraph style. We only need to know indent and line height.
    NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
    pStyle.maximumLineHeight    = (style.lineHeight > 0.0) ? style.lineHeight : self.styles.page.lineHeight;
    pStyle.firstLineHeadIndent  = style.firstLineIndent;
    pStyle.headIndent           = style.indent;
    
    if (_paragraphStyles == nil) _paragraphStyles = NSMutableDictionary.new;
    
    // Don't store the style if it's dynamic
    if (!style.dynamicStyle) _paragraphStyles[lineType] = pStyle;
    
    return pStyle;
}


#pragma mark - CONT'D and (MORE)

/// Returns a `Line` object with character cue followed by `(CONT'D)` extension for continuing dialogue block after a page break.
- (Line*)contdLineFor:(Line*)line
{
	NSString *extension = BeatScreenplayElements.shared.contd;
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
- (Line*)moreLineFor:(Line*)line
{
	LineType type = (line.isDualDialogue) ? dualDialogueMore : more;
	Line *more = [Line.alloc initWithString:BeatScreenplayElements.shared.more type:type];
	more.position = line.position;
	more.unsafeForPageBreak = YES;
	return more;
}

- (NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>*)titlePage {
    return self.titlePageContent;
}

- (BeatParagraphPaginationMode)paragraphPaginationMode
{
    if (!self.styles.overrideParagraphPaginationMode) {
        return (BeatParagraphPaginationMode)[BeatUserDefaults.sharedDefaults getInteger:BeatSettingParagraphPaginationMode];
    } else {
        return BeatParagraphPaginationModeDefault;
    }
}

- (NSArray<Line*>*)getProducedLinesFor:(Line*)line
{
    // We need to check if this line actually produces multiple lines
    NSAttributedString* attrStr = [line attributedStringForOutputWith:self.settings];
    NSInteger lineBreakIndex = [attrStr.string rangeOfString:@"\n"].location;
    
    NSMutableArray<Line*>* components = NSMutableArray.new;
    while (lineBreakIndex != NSNotFound) {
        NSInteger lineBreakIndex = [attrStr.string rangeOfString:@"\n"].location;
        bool stop = false;
        Line* newLine;
        if (lineBreakIndex == NSNotFound) {
            newLine = [Line.alloc initWithString:[Line attributedStringToFountain:attrStr] type:line.type];
            stop = true;
        } else {
            NSAttributedString* head = [attrStr attributedSubstringFromRange:NSMakeRange(0, lineBreakIndex)];
            newLine = [Line.alloc initWithString:[Line attributedStringToFountain:head] type:line.type];
            // Move on to next part of the attributed string
            attrStr = [attrStr attributedSubstringFromRange:NSMakeRange(lineBreakIndex+1, attrStr.length - lineBreakIndex - 1)];
        }
        
        if (newLine != nil) {
            [newLine resetFormatting];
            newLine.beginsNewParagraph = true;
            [components addObject:newLine];
        }
        
        if (stop) break;
    }
    
    return components;
}


@end
