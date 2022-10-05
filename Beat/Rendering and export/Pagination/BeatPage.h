//
//  BeatPage.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Line.h"
#import "BeatPageDelegate.h"

@interface BeatPage:NSObject
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
@property (atomic) NSMutableArray *items;
@property (atomic) NSInteger y;
@property (atomic) NSInteger maxHeight;
- (NSUInteger)count;
- (NSMutableArray*)contents;
- (NSInteger)remainingSpace;
- (NSInteger)remainingSpaceWithBlock:(NSArray<Line*>*)block;
- (void)addBlock:(NSArray<Line*>*)block height:(NSInteger)height;
- (void)clear;
@end

