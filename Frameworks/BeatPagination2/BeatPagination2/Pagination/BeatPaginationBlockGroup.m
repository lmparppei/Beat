//
//  BeatPaginationBlockGroup.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationBlockGroup.h"
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import "BeatPagination.h"
#import "BeatPaginationBlock.h"
#import "BeatPageBreak.h"

@interface BeatPaginationBlockGroup()
@end

@implementation BeatPaginationBlockGroup

+(BeatPaginationBlockGroup*)withBlocks:(NSArray<BeatPaginationBlock*>*)blocks delegate:(id<BeatPageDelegate>)delegate
{
	return [BeatPaginationBlockGroup.alloc initWithBlocks:blocks delegate:delegate];
}

-(instancetype)initWithBlocks:(NSArray<BeatPaginationBlock*>*)blocks delegate:(id<BeatPageDelegate>)delegate
{
	self = [super init];
	if (self) {
		_blocks = blocks;
        _delegate = delegate;
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
-(NSArray*)breakGroupWithRemainingSpace:(CGFloat)remainingSpace styles:(BeatStylesheet*)styles
{
	CGFloat space = remainingSpace;
	NSMutableArray<BeatPaginationBlock*>* passedBlocks = NSMutableArray.new;
	
	NSMutableArray<Line*>* onThisPage = NSMutableArray.new;
	NSMutableArray<Line*>* onNextPage = NSMutableArray.new;
	
	NSInteger idx = 0;
	BeatPaginationBlock *offendingBlock;
    NSArray* brokenBlock;
    
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
            
            // Let's try to break the element apart
            brokenBlock = [block breakBlockWithRemainingSpace:space];
            
			break;
		}
	}
	
	if (passedBlocks.count == 1) {
		// The starting item of a block is *never* left behind. We'll need to try to break the next item.
        BeatPaginationBlock* retainedBlock = [BeatPaginationBlock withLines:brokenBlock[0] delegate:_delegate];
        
        // We'll require at least 2 lines to lay on this page. If it's less, we'll just roll the scene on next page. (3 = 2 + top margin)
        if (brokenBlock.count && retainedBlock.height < _delegate.styles.page.lineHeight * 3) {
            //BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:[self lines].firstObject lineHeight:lineHeight reason:@"2nd element in block group didn't fit on this page"];
            BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"2nd element in block group didn't fit on this page"];
            return @[@[], [self lines], pageBreak];
        }
	}
	
	// Add anything that was passed
	for (BeatPaginationBlock* passedBlock in passedBlocks) {
		[onThisPage addObjectsFromArray:passedBlock.lines];
	}
	
	if (offendingBlock == nil) {
		// There was no offending block for some reason?
		// To be on the safe side, push everything on next page.
        // BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithY:0.0 element:[self lines].firstObject lineHeight:styles.page.lineHeight reason:@"Something went wrong when breaking a block"];
        BeatPageBreak* pageBreak = [BeatPageBreak.alloc initWithVisibleIndex:0 element:self.lines.firstObject attributedString:nil reason:@"Something went wrong when breaking a block"];
		return @[@[], self.lines, pageBreak];
	}
		
	NSArray* pageBreak = [offendingBlock breakBlockWithRemainingSpace:space];
	
	NSArray<Line*>* remainingLines = pageBreak[0];
	[onThisPage addObjectsFromArray:remainingLines];
	
	NSArray<Line*>* splitLines = pageBreak[1];
	[onNextPage addObjectsFromArray:splitLines];
	
	// If there were more blocks that didn't get handled, add them on next page
	if (offendingBlock != self.blocks.lastObject) {
		NSArray* remainingBlocks = [_blocks subarrayWithRange:NSMakeRange(idx+1, _blocks.count-idx-1)];
		for (BeatPaginationBlock *remainingBlock in remainingBlocks) {
			[onNextPage addObjectsFromArray:remainingBlock.lines];
		}
	}

	BeatPageBreak* pageBreakItem = pageBreak[2];
	return @[onThisPage, onNextPage, pageBreakItem];
}

- (NSArray<Line*>*)lines
{
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	
	return lines;
}

@end
