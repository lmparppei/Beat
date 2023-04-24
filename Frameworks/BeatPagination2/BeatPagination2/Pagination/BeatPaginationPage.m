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
	self = [super init];
	
	if (self) {
		self.delegate = delegate;
		self.blocks = NSMutableArray.new;
		self.maxHeight = _delegate.maxPageHeight;
	}
	
	return self;
}

/**
 This method returns page content as `NSAttributedString`. To get it working, you'll need to hook up a `BeatRendererDelegate` instance to the paginator. macOS and iOS require their own respective classes which comply to the protocol.
 */
-(NSAttributedString*)attributedString {
	if (self.delegate == nil) {
		NSLog(@"WARNING: No delegate for page.");
	}
	if (self.delegate.renderer == nil) {
		NSLog(@"WARNING: No renderer set for paginator");
		return NSAttributedString.new;
	}
	
	// Create page number header
	NSInteger pageNumber = [self.delegate.pages indexOfObject:self];
	if (pageNumber == NSNotFound) pageNumber = self.delegate.pages.count - 1;
	
	NSMutableAttributedString* result = [NSMutableAttributedString.alloc initWithAttributedString:[self.delegate.renderer pageNumberBlockForPageNumber:pageNumber + 1]];
	
	// If the page hasn't been rendered, do it now.
	if (_renderedString == nil) {
		// Make a copy of the block so we won't disturb other threads
		NSArray* blocks = self.safeBlocks;
		NSMutableAttributedString* renderedString = NSMutableAttributedString.new;
		
		for (BeatPaginationBlock* block in blocks) {
			bool firstElement = (block == blocks.firstObject) ? true : false;
			
			NSAttributedString* renderedBlock = [self.delegate.renderer renderBlock:block firstElementOnPage:firstElement];
			[renderedString appendAttributedString:renderedBlock];
		}
		
		_renderedString = renderedString;
	}
	
	// Add rendered content to the header block
	[result appendAttributedString:_renderedString];
	return result;
}

- (void)invalidateRender {
	_renderedString = nil;
}

-(NSArray*)lines {
	NSMutableArray* lines = NSMutableArray.new;
	for (BeatPaginationBlock* block in self.safeBlocks) {
		[lines addObjectsFromArray:block.lines];
	}
	return lines;
}

-(NSArray*)safeBlocks {
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
	NSArray<Line*>* lines = self.lines;
		Line* line = lines[index];
	
	bool isDialogue = (line.isDialogue || line.isDualDialogue) ? true : false;
	
	// This line should be safe
	if (isDialogue || line.unsafeForPageBreak) {
		while (index >= 0) {
			Line* l = lines[index];
			
			if (!isDialogue && !l.unsafeForPageBreak) break;
			else if (isDialogue && l.type == character) break;
			else if (isDialogue && !(l.isDialogue || l.isDualDialogue)) break;
			
			index -= 1;
		}
	}
	
	// Let's also check if the line is preceded by a element which affects pagination
	if (index > 0) {
		LineType precedingType = lines[index - 1].type;
		if (precedingType == heading || precedingType == shot) {
			index -= 1;
		}
	}
	
	return index;
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

/// Returns the range of the screenplay which current page represents.
-(NSRange)representedRange {
	NSInteger begin = NSNotFound;
	NSInteger end = NSNotFound;
	NSArray<Line*>* lines = self.lines;
	
	for (Line* line in lines) {
		if (!line.unsafeForPageBreak) {
			begin = line.position;
			break;
		}
	}
	
	NSInteger i = lines.count - 1;
	while (i >= 0) {
		Line *line = lines[i];
		if (!line.unsafeForPageBreak) {
			end = NSMaxRange(line.range);
			break;
		}
		i -= 1;
	}
	
	if (begin == NSNotFound || end == NSNotFound)
		return NSMakeRange(NSNotFound, 0);
	else
		return NSMakeRange(begin, end - begin);
}

-(void)addBlock:(BeatPaginationBlock*)block {
	[self.blocks addObject:block];
	[self invalidateRender];
}

-(void)clearUntil:(Line*)line {
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


@end
