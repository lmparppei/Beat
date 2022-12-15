//
//  BeatPaginationPage.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol BeatPageDelegate;
@class BeatPaginationBlock;
@class BeatPageBreak;

@interface BeatPaginationPage : NSObject
@property (nonatomic) BeatPageBreak *pageBreak;
@property (nonatomic) NSMutableArray<BeatPaginationBlock*>* blocks;

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate;
-(void)addBlock:(BeatPaginationBlock*)block;
-(NSRange)representedRange;
@end

NS_ASSUME_NONNULL_END
