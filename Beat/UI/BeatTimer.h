//
//  BeatTimer.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTimerView.h"

@interface BeatTimer : NSObject <BeatTimerViewDelegate>
@property IBOutlet BeatTimerView *timerView;
@property IBOutlet NSPanel *inputPanel;
@property IBOutlet NSTextField *minutes;
@property IBOutlet NSTextField *label;
@property IBOutlet NSWindow *window;

@property IBOutlet NSButton *startButton;
@property IBOutlet NSButton *resetButton;
@property IBOutlet NSButton *pauseButton;

- (void)showTimer;
- (IBAction)pause:(id)sender;

@end

