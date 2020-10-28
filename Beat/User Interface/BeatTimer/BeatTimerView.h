//
//  BeatTimerView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatTimerViewDelegate <NSObject>
- (IBAction) pause:(id)sender;
- (void)showTimer;
@end

@interface BeatTimerView : NSView
@property (nonatomic) CGFloat progress;
@property (nonatomic) bool finished;
@property IBOutlet id<BeatTimerViewDelegate> delegate;
-(void)finish;
-(void)reset;
-(void)update;
-(void)start;

@end

NS_ASSUME_NONNULL_END
