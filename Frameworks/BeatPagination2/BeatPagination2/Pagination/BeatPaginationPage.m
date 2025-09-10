//
//  BeatPaginationPage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class represents a page. It contains the blocks generated from screenplay during pagination
 and knows the height of its content and remaining space etc.
 
 */
#import <BeatParsing/BeatParsing.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import "BeatPaginationPage.h"
#import "BeatPaginationBlock.h"
#import "BeatPageBreak.h"


@interface BeatPaginationPage()
@property (nonatomic) NSMutableArray<Line*>* lines;
@property (nonatomic) NSAttributedString* renderedString;
@end

@implementation BeatPaginationPage

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate {
    return [BeatPaginationPage.alloc initWithDelegate:delegate blocks:nil pageBreak:nil];
}

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate blocks:(NSMutableArray*)blocks pageBreak:(BeatPageBreak*)pageBreak {
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        self.maxHeight = _delegate.maxPageHeight;
        
        self.pageBreak = pageBreak;
        self.blocks = (blocks != nil) ? blocks : NSMutableArray.new;
    }
    
    return self;
}

-(BeatPaginationPage*)copyWithDelegate:(id)delegate {
    // Move ownership of blocks
    for (BeatPaginationBlock* block in self.blocks) block.delegate = delegate;
    
    BeatPaginationPage* page = [BeatPaginationPage.alloc initWithDelegate:delegate blocks:self.blocks pageBreak:self.pageBreak];
    return page;
}

/// Custom page number getter. Iterates each line, which is not optimal, but this is how it goes.
- (NSString *)customPageNumber
{
    NSString* customPageNumber = nil;
    
    for (Line* line in self.lines) {
        NSString* forcedPageNumber = line.forcedPageNumber;
        if (forcedPageNumber != nil) customPageNumber = forcedPageNumber;
    }
    
    return customPageNumber;
}

/**
 This method returns page content as `NSAttributedString`. classes which comply to the protocol.
 */
-(NSAttributedString*)attributedString
{
    if (self.delegate == nil) {
        NSLog(@"WARNING: No delegate for page.");
    }
    if (self.delegate.renderer == nil) {
        NSLog(@"WARNING: No renderer set for paginator but asking for attributed string for page.");
        return NSAttributedString.new;
    }
    
    // Create page number header
    NSMutableAttributedString* result = [NSMutableAttributedString.alloc initWithAttributedString:[self.delegate.renderer pageNumberBlockForPage:self]];
    
    NSMutableAttributedString* renderedString;
    
    // If the page hasn't been rendered, do it now.
    if (_renderedString == nil || _renderedString.length == 0) {
        // Make a copy of the block so we won't disturb other threads
        NSArray* blocks = self.safeBlocks;
        renderedString = NSMutableAttributedString.new;
        
        for (BeatPaginationBlock* block in blocks) {
            bool firstElement = (block == blocks.firstObject) ? true : false;
            
            NSAttributedString* renderedBlock = [self.delegate.renderer renderBlock:block firstElementOnPage:firstElement];
            if (renderedBlock != nil) [renderedString appendAttributedString:renderedBlock];
        }
        
        _renderedString = renderedString;
    } else {
        renderedString = _renderedString.copy;
    }
    
    // Add rendered content to the header block
    if (renderedString != nil) [result appendAttributedString:self.renderedString];
    return result;
}

- (void)invalidateRender {
    _renderedString = nil;
}

-(NSArray*)lines {
    if (_lines != nil) return _lines;
    NSArray* blocks = self.safeBlocks;
    
    NSMutableArray* lines = [NSMutableArray arrayWithCapacity:blocks.count * 2]; // This is an average line count per page
    for (BeatPaginationBlock* block in blocks) {
        [lines addObjectsFromArray:block.lines];
    }
    
    _lines = lines;
    return lines;
}

-(NSArray*)safeBlocks {
    if (self.blocks == nil) return @[];
    
    NSArray* blocks = [NSArray arrayWithArray:self.blocks];
    return blocks;
}

-(CGFloat)remainingSpace {
    CGFloat height = 0.0;
    NSArray* blocks = self.safeBlocks;
    for (BeatPaginationBlock *block in blocks) {
        height += block.height;
        
        // Remove top margin for the first object
        if (block == blocks.firstObject) {
            height -= block.topMargin;
        }
    }
    
    return _maxHeight - height;
}


/// Finds the index which we can restart pagination from. It's kind of a reverse block search.
- (NSInteger)findSafeLineFromIndex:(NSInteger)index {
    // OK, this code doesn't make any sense.
    // I must have been tired, drunk or in psychosis.
    // After some minor blind fixes, it appears to work, though.
    
    NSArray<Line*>* lines = self.lines;
    Line* line = lines[index];
    
    bool isDialogue = (line.isDialogue || line.isDualDialogue) ? true : false;
    
    // Don't allow pagination to begin at unsafe lines or mid-dialogue
    if (isDialogue || line.unsafeForPageBreak) {
        index--;
        while (index >= 0) {
            Line* l = lines[index];
            
            if (!l.isDualDialogue) {
                if (isDialogue && l.type == character && !l.unsafeForPageBreak) break;
                else if (isDialogue && !(l.isDialogue || l.isDualDialogue)) break;
                else if (!isDialogue && !l.isDialogue && !l.unsafeForPageBreak) break;
            }
            
            index -= 1;
        }
    }
    
    // Let's also check if the line is preceded by an element which affects pagination
    if (index > 0) {
        LineType precedingType = lines[index - 1].type;
        if (precedingType == heading || precedingType == shot) {
            index -= 1;
        }
    }
    
    return index;
}

/// Returns a RELATIVE value for position of block (`0...1`)
- (CGFloat)positionOfBlockForLine:(Line*)line
{
    NSInteger i = [self blockIndexForLine:line];
    if (i == NSNotFound) {
        return -1.0;
    }
    
    BeatPaginationBlock* block = self.blocks[i];
    return [self positionOfBlock:block];
}

/// Returns the ACTUAL POINT value for position of block
- (CGFloat)actualPositionOfBlockForLine:(Line*)line
{
    NSInteger i = [self blockIndexForLine:line];
    if (i == NSNotFound) {
        return -1.0;
    }
    
    BeatPaginationBlock* block = self.blocks[i];
    return [self positionOfBlock:block relative:false];
}

/// Returns the ACTUAL POINT value for position of block
- (CGFloat)actualPositionOfBlock:(BeatPaginationBlock*)block
{
    return [self positionOfBlock:block relative:false];
}

/// Returns a RELATIVE value for position of block (`0...1`)
- (CGFloat)positionOfBlock:(BeatPaginationBlock*)block
{
    return [self positionOfBlock:block relative:true];
}

/// Returns the position of given block on page.
/// @param block The paginated block
/// @param relative If set true, the method returns a relative value (0...1) instead of the actual position in points
- (CGFloat)positionOfBlock:(BeatPaginationBlock*)block relative:(bool)relative
{
    CGFloat height = 0.0;
    NSInteger i = [self.blocks indexOfObject:block];
    if (i == NSNotFound) {
        return -1.0;
    }
    
    for (NSInteger k=0; k<i; k++) {
        BeatPaginationBlock* b = self.blocks[k];
        height += b.height;
        
        // Remove top margin for first object
        if (k == 0) height -= b.topMargin;
    }
    
    if (relative) return height / self.maxHeight;
    else return height;
}

/// Returns index for the line in given position
- (NSInteger)indexForLineAtPosition:(NSInteger)position {
    NSInteger index = self.lines.count - 1;
    
    while (index >= 0) {
        Line* l = self.lines[index];
        if (NSLocationInRange(position, l.range) || position > NSMaxRange(l.range)) {
            return index;
        }
        
        index -= 1;
    }
    
    return NSNotFound;
}

/// Returns the index of a block (on this page) containing the given line.
- (NSInteger)blockIndexForLine:(Line*)line {
    for (NSInteger i=0; i<_blocks.count; i++) {
        BeatPaginationBlock* block = _blocks[i];
        
        for (NSInteger j=0; j<block.lines.count; j++) {
            Line* l = block.lines[j];
            
            if ([l.uuid uuidEqualTo:line.uuid]) {
                return i;
            }
        }
    }
    
    return NSNotFound;
}

- (NSInteger)nearestBlockIndexForLine:(Line*)line {
    return [self nearestBlockIndexForRange:line.range];
}
    
- (NSInteger)nearestBlockIndexForRange:(NSRange)range {
    for (NSInteger i=0; i<_blocks.count; i++) {
        BeatPaginationBlock* block = _blocks[i];
        
        for (NSInteger j=0; j<block.lines.count; j++) {
            Line* l = block.lines[j];
            
            // Return the current index if we are inside current range, OR if we've gone past it.
            if (NSLocationInRange(range.location, l.range) || (NSMaxRange(range) < l.position)) {
                return i;
            }
        }
    }
    
    return NSNotFound;
}

- (NSRange)rangeForLocation:(NSInteger)location
{
	__block NSRange prevRange = NSMakeRange(NSNotFound, 0);
	__block NSRange result = NSMakeRange(NSNotFound, 0);
	
	NSAttributedString* attrStr = self.attributedString;
	[attrStr enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, attrStr.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;
		if (line == nil) return;
		
		if (NSLocationInRange(location, line.textRange)) {
			result = range;
			*stop = true;
		}
		else if (NSMaxRange(line.range) > location) {
			result = prevRange;
			*stop = true;
		}
		
		prevRange = range;
	}];
	
	return result;
}


/// Returns the pagination-safe range of the screenplay which current page represents.
-(NSRange)safeRange {
    return [self safeRangeWithUUIDs:nil];
}
-(NSRange)safeRangeWithUUIDs:(NSMapTable<NSUUID*, Line*>* _Nullable)uuids
{
	Line* begin = nil;
	Line* end = nil;
	NSArray<Line*>* lines = self.lines;
	
	for (Line* line in lines) {
		if (!line.unsafeForPageBreak) {
            begin = line;
			break;
		}
	}
	
	NSInteger i = lines.count - 1;
	while (i >= 0) {
		Line *line = lines[i];
		if (!line.unsafeForPageBreak) {
            end = line;
			break;
		}
		i -= 1;
	}
    
    if (uuids == nil) uuids = self.delegate.uuids;
    
    NSRange result;
	if (begin == nil || end == nil)
		result = NSMakeRange(NSNotFound, 0);
    else {
        // Get *actual* lines by UUID
        Line* lBegin = [uuids objectForKey:begin.uuid];
        Line* lEnd = [uuids objectForKey:end.uuid];
        result =  NSMakeRange(lBegin.position, NSMaxRange(lEnd.range) - lBegin.position);
    }

    return result;
}

/// Returns the **ACTUAL** range that the page probably represents
-(NSRange)representedRange
{
    Line* begin = nil;
    Line* end = nil;
    NSArray<Line*>* lines = self.lines;
    
    for (Line* line in lines) {
        if (!line.unsafeForPageBreak) {
            begin = line;
            break;
        }
    }
    
    NSInteger i = lines.count - 1;
    while (i >= 0) {
        Line *line = lines[i];
        if (line.position != NSNotFound) {
            end = line;
            break;
        }
        i -= 1;
    }
    
    NSMapTable* uuids = self.delegate.uuids;
    
    if (begin == nil || end == nil) {
        return NSMakeRange(NSNotFound, 0);
    } else {
        // Get *actual* lines by UUID
        Line* lBegin = [uuids objectForKey:begin.uuid];
        Line* lEnd = [uuids objectForKey:end.uuid];
        
        NSRange beginRange = lBegin.range;
        NSRange endRange = lEnd.range;
        
        if (lBegin == nil) beginRange = begin.range;
        if (lEnd == nil) endRange = end.range;
        
        NSRange range = NSMakeRange(beginRange.location, NSMaxRange(endRange) - beginRange.location);
        return range;
    }
}

 
-(void)addBlock:(BeatPaginationBlock*)block {
    // Invalidate current line array and rendered string
    _lines = nil;
    
	[self.blocks addObject:block];
	[self invalidateRender];
}

-(void)clearUntil:(Line*)line {
    // Invalidate current line array
    _lines = nil;
    
	NSArray<Line*>* lines = self.lines;
	
	NSInteger i = [lines indexOfObject:line];
	if (i == NSNotFound) {
		NSLog(@"ERROR: Line not found on page.");
		return;
	}
	
	// Iterate blocks and store stuff until given line
	NSMutableArray<BeatPaginationBlock*>* blocks = NSMutableArray.new;
	for (BeatPaginationBlock* block in self.safeBlocks) {
		if ([block containsLine:line]) break;
		[blocks addObject:block];
	}
	[self.blocks setArray:blocks];
	
	// Invalidate current render
	[self invalidateRender];
}

- (bool)hasForcedPageBreak
{
    return (self.lines.lastObject.type == pageBreak);
}

- (bool)hasScene
{
    for (Line* l in self.lines) {
        if (l.type == heading) return true;
    }
    return false;
}

- (NSString*)pageNumberForPrinting
{
    NSString* customPageNumber = self.customPageNumber;
    NSString* pageNumber;
    
    if (customPageNumber == nil) pageNumber = [NSString stringWithFormat:@"%lu.", self.pageNumber];
    else pageNumber = customPageNumber.trim;
    
    return pageNumber;
}

@end
