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
#import "BeatPaginationPage.h"
#import "BeatPaginationBlock.h"
#import "BeatPageBreak.h"
#import "Beat-Swift.h"

@interface BeatPaginationPage()
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
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
	if (self.delegate.renderer == nil) {
		NSLog(@"WARNING: No renderer set for paginator");
		return NSAttributedString.new;
	}
	
	// If the page hasn't been rendered, do it now.
	if (_renderedString == nil) {
		NSInteger pageNumber = [self.delegate.pages indexOfObject:self];
		if (pageNumber == NSNotFound) pageNumber = self.delegate.pages.count - 1;
		
		NSMutableAttributedString* string = NSMutableAttributedString.new;
		
		// Add page number header
		NSAttributedString* header = [self.delegate.renderer pageNumberBlockForPageNumber:pageNumber + 1];
		[string appendAttributedString:header];
		
		for (BeatPaginationBlock* block in self.blocks) {
			bool firstElement = (block == self.blocks.firstObject) ? true : false;
			NSAttributedString* renderedBlock = [self.delegate.renderer renderBlock:block firstElementOnPage:firstElement];
			[string appendAttributedString:renderedBlock];
		}
		
		_renderedString = string;
	}
	
	return _renderedString;
}
- (void)invalidateRender {
	_renderedString = nil;
}


-(NSArray*)lines {
	NSMutableArray* lines = NSMutableArray.new;
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	return lines;
}

-(CGFloat)remainingSpace {
	CGFloat height = 0.0;
	for (BeatPaginationBlock *block in self.blocks) {
		height += block.height;
		
		// Remove top margin for the first object
		if (block == self.blocks.firstObject) {
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
			Line* line = block.lines[j];
			if ([line.uuid isEqualTo:line.uuid]) {
				return i;
			}
		}
	}
	
	return NSNotFound;
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
		}
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
	for (BeatPaginationBlock* block in self.blocks) {
		if ([block containsLine:line]) break;
		[blocks addObject:block];
	}
	self.blocks = blocks;
	
	// Invalidate current render
	[self invalidateRender];
}

@end
