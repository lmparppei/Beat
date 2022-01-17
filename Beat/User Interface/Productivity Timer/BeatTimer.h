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

@interface BeatTimer : NSObject <BeatTimerViewDelegate>
@property (weak) id<BeatTimerDelegate> delegate;
@property (weak) IBOutlet BeatTimerView *timerView;
@property (weak) IBOutlet NSPanel *inputPanel;
@property (weak) IBOutlet NSTextField *minutes;
@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *resetButton;
@property (weak) IBOutlet NSButton *pauseButton;

@property (nonatomic) NSTimer *timer;

@property NSInteger charactersTyped;

- (bool)running;
- (void)showTimer;
- (IBAction)pause:(id)sender;

@end

