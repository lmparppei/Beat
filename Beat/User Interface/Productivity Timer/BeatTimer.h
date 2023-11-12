//
//  BeatTimer.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTimerView.h"

@protocol BeatTimerDelegate <NSObject>
- (NSString*)text;
@end

@interface BeatTimer : NSResponder <BeatTimerViewDelegate>
@property (weak) id<BeatTimerDelegate> delegate;
@property (weak) IBOutlet BeatTimerView *timerView;
@property (weak) IBOutlet NSWindow *window;

@property (nonatomic) __block NSInteger timeLeft;
@property (nonatomic) __block NSInteger timeTotal;
@property (nonatomic) __block NSInteger timeOriginal;
@property (nonatomic) __block bool paused;
@property (nonatomic) __block bool done;

@property (nonatomic) NSTimer *timer;

@property NSInteger charactersTyped;

- (bool)running;
- (void)showTimer;
- (void)pause;

@end

