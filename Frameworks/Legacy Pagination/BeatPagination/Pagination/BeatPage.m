//
//  BeatPage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginator.h"
#import "BeatPage.h"

@implementation BeatPage

- (instancetype)init {
	self = [super init];
	self.items = NSMutableArray.new;
	self.y = 0;
	return self;
}

- (void)clear {
	[self.items removeAllObjects];
	self.y = 0;
}

- (NSInteger)remainingSpace {
	NSInteger space = self.maxHeight - self.y;
	if (self.items.count) space -= BeatPaginator.lineHeight;
	return space;
}

- (NSInteger)remainingSpaceWithBlock:(NSArray<Line*>*)block {
	NSInteger space = self.maxHeight - self.y;
	if (self.items.count) space -= [self.delegate spaceBeforeForLine:block.firstObject];
	return space;
}

- (NSUInteger)count {
	return self.items.count;
}

- (void)add:(Line*)line height:(NSInteger)height {
	
	if (height == -1) {
		// This is a temporary element created for pagination (such as MORE)
		line.heightInPaginator = [self.delegate heightForBlock:@[line]];
		if (self.items.count) self.y += [self.delegate spaceBeforeForLine:line];
	}
	
	self.y += line.heightInPaginator;
	[self.items addObject:line];
}

- (void)addBlock:(NSArray<Line*>*)block height:(NSInteger)height {
	for (Line* line in block) {
		[self.items addObject:line];
	}
	
	//if (self.items.count) self.y += [BeatPaginator spaceBeforeForLine:block.firstObject];
	self.y += height;
}

- (NSMutableArray*)contents {
	return self.items.copy;
}

@end
