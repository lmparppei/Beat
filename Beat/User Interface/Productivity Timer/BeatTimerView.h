//
//  BeatTimerView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatTimerViewDelegate <NSObject>
- (void)pause;
- (void)showTimer;
@end

@interface BeatTimerView : NSView
@property (nonatomic) CGFloat progress;
@property (nonatomic) bool finished;
@property (weak) IBOutlet id<BeatTimerViewDelegate> delegate;
-(void)finish;
-(void)reset;
-(void)update;
-(void)start;

@end

NS_ASSUME_NONNULL_END
