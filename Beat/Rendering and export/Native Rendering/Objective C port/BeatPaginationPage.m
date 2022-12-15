//
//  BeatPaginationPage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationPage.h"
#import "BeatPagination.h"
#import "BeatPaginationBlock.h"
#import "Beat-Swift.h"

@interface BeatPaginationPage()
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
@property (nonatomic) NSMutableArray<Line*>* lines;

@end

@implementation BeatPaginationPage

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate {
	self = [super init];
	
	if (self) {
		self.delegate = delegate;
		self.blocks = NSMutableArray.new;
	}
	
	return self;
}

-(NSArray*)lines {
	NSMutableArray* lines = NSMutableArray.new;
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	return lines;
}

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
}


@end
