//
//  BeatPaginationBlockGroup.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationBlockGroup.h"
#import <BeatParsing/BeatParsing.h>
#import "BeatPagination.h"
#import "BeatPaginationBlock.h"
#import "Beat-Swift.h"

@interface BeatPaginationBlockGroup()
@end

@implementation BeatPaginationBlockGroup

+(BeatPaginationBlockGroup*)withBlocks:(NSArray<BeatPaginationBlock*>*)blocks {
	return [BeatPaginationBlockGroup.alloc initWithBlocks:blocks];
}

-(instancetype)initWithBlocks:(NSArray<BeatPaginationBlock*>*)blocks {
	self = [super init];
	if (self) {
		_blocks = blocks;
	}
	return self;
}

-(CGFloat)height {
	CGFloat height = 0.0;
	for (BeatPaginationBlock* block in self.blocks) {
		height += block.height;
	}
	
	return height;
}

/**
 - returns `NSArray` with `[onThisPage<Line*>, onNextPage<Line*>, BeatPageBreak]`
 */
-(NSArray*)breakGroupWithRemainingSpace:(CGFloat)remainingSpace {
	CGFloat space = remainingSpace;
	NSMutableArray<BeatPaginationBlock*>* passedBlocks = NSMutableArray.new;
	
	NSMutableArray<Line*>* onThisPage = NSMutableArray.new;
	NSMutableArray<Line*>* onNextPage = NSMutableArray.new;
	
	NSInteger idx = 0;
	BeatPaginationBlock *offendingBlock;
	
	for (BeatPaginationBlock *block in self.blocks) {
		CGFloat h = block.height;
		
		if (h < space) {
			// This block fits
			[passedBlocks addObject:block];
			space -= h;
			idx += 1;
			continue;
		}
		else {
			// This block won't fit.
			offendingBlock = block;
			break;
		}
	}
	
	if (offendingBlock == nil) {
		// There was no offending block for some reason?
		// To be on the safe side, push everything on next page.
		return @[@[], [self lines], [BeatPageBreak.alloc initWithY:0 element:[self lines].firstObject reason:@"Something went wrong when breaking a block"]];
	}

	NSArray* pageBreak = [offendingBlock breakBlockWithRemainingSpace:space];
	
	for (BeatPaginationBlock* passedBlock in passedBlocks) {
		[onThisPage addObjectsFromArray:passedBlock.lines];
	}
	
	NSArray<Line*>* remainingLines = pageBreak[0];
	[onThisPage addObjectsFromArray:remainingLines];
	
	NSArray<Line*>* splitLines = pageBreak[1];
	[onNextPage addObjectsFromArray:splitLines];
	
	// If there were more blocks that didn't get handled, add them on next page
	if (offendingBlock != self.blocks.lastObject) {
		NSArray* remainingBlocks = [_blocks subarrayWithRange:NSMakeRange(idx+1, _blocks.count-idx)];
		[onNextPage addObjectsFromArray:remainingBlocks];
	}

	BeatPageBreak* pageBreakItem = pageBreak[2];
	return @[onThisPage, onNextPage, pageBreakItem];
}

- (NSArray<Line*>*)lines {
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	
	return lines;
}

@end
