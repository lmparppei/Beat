//
//  BeatTimer.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTimerView.h"

@protocol BeatTimerDelegate <NSObject>
- (NSString*) getText;
@end

@interface BeatTimer : NSObject <BeatTimerViewDelegate>
@property (weak) id<BeatTimerDelegate> delegate;
@property IBOutlet BeatTimerView *timerView;
@property IBOutlet NSPanel *inputPanel;
@property IBOutlet NSTextField *minutes;
@property IBOutlet NSTextField *label;
@property IBOutlet NSWindow *window;

@property IBOutlet NSButton *startButton;
@property IBOutlet NSButton *resetButton;
@property IBOutlet NSButton *pauseButton;

@property NSInteger charactersTyped;

- (bool)running;
- (void)showTimer;
- (IBAction)pause:(id)sender;

@end

