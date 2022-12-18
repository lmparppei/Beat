//
//  BeatPaginationBlockGroup.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class BeatPaginationBlock;
@class Line;

@interface BeatPaginationBlockGroup : NSObject
@property (nonatomic) NSArray<BeatPaginationBlock*>* blocks;
@property (nonatomic) CGFloat height;
+ (BeatPaginationBlockGroup*)withBlocks:(NSArray<BeatPaginationBlock*>*)blocks;
- (NSArray*)breakGroupWithRemainingSpace:(CGFloat)remainingSpace;
- (NSArray<Line*>*)lines;
@end

NS_ASSUME_NONNULL_END
