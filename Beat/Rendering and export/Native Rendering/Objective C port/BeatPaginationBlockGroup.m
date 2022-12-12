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
@property (nonatomic) NSArray<BeatPaginationBlock*>* blocks;
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

-(void)splitGroupWithRemainingSpace:(CGFloat)remainingSpace {
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
	
	if (offendingBlock != nil) {
		BeatPageBreak *pageBreakItem;
		
		// NSArray *pageBreak = [offendingBlock splitBlockWithRemainingSpace:space];
		
	/*
	 var pageBreakItem:BeatPageBreak
	 let pageBreak = offendingBlock!.splitBlock(remainingSpace: space)
	 
	 // Is there something left on current page?
	 if pageBreak.0.count > 0 {
		 for passedBlock in passedBlocks { onThisPage.append(contentsOf: passedBlock.lines) }
		 onThisPage.append(contentsOf: pageBreak.0)
	 }
	 
	 // Did something spill on next page?
	 if pageBreak.1.count > 0 {
		 onNextPage.append(contentsOf: pageBreak.1)
	 }
	 
	 // If there were more blocks that didn't get handled, add them on next page
	 if (offendingBlock != blocks.last!) {
		 for i in idx+1..<blocks.count {
			 let b = blocks[i]
			 onNextPage.append(contentsOf: b.lines)
		 }
	 }
	 
	 pageBreakItem = pageBreak.2
	 
	 return (onThisPage, onNextPage, pageBreakItem)
	 */
	}
}

- (NSArray<Line*>*)lines {
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	
	return lines;
}

@end
