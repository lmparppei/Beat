//
//  BeatTimeline.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatTimelineDelegate <NSObject>

- (NSRange)selectedRange;
- (NSMutableArray*)getOutlineItems;

@end

@interface BeatTimeline : NSView 

@property (nonatomic) NSArray* outline;
@property (nonatomic) id<BeatTimelineDelegate> delegate;

- (void)reload:(NSArray*)scenes;
@end

NS_ASSUME_NONNULL_END
