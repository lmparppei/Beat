//
//  BeatTimer.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "BeatTimer.h"

@interface BeatTimer ()
@property (nonatomic) __block NSInteger timeLeft;
@property (nonatomic) __block NSInteger timeTotal;
@property (nonatomic) __block bool paused;
@property (nonatomic) __block bool done;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSPopover *popover;
@end

@implementation BeatTimer

- (void)showTimer {
	[_window beginSheet:_inputPanel completionHandler:nil];
}
- (IBAction)setTimer:(id)sender {
	// Check if timer is already running
	if ([_startButton.title isEqualToString:@"Reset"]) {
		[self reset];
	} else {
		CGFloat seconds = [_minutes.stringValue floatValue] * 60.0;
		if (seconds == 0) seconds = 1;
		[self timerFor:round(seconds)];
		
		[_window endSheet:_inputPanel];
	}
}
- (IBAction)close:(id)sender {
	[_window endSheet:_inputPanel];
}

- (void)timerFor:(NSInteger)seconds {
	_done = NO;
	
	[_resetButton setHidden:NO];
	[_startButton setTitle:@"Reset"];
	[_pauseButton setHidden:NO];
	[_label setHidden:YES];
	
	[_minutes setEnabled:NO];
	
	[_timerView setHidden:NO];
	_timeLeft = seconds;
	_timeTotal = seconds;
	
	self.timerView.progress = 1;
	[self.timerView setNeedsDisplay:YES];
	
	
	[_timer invalidate];
	[_timerView reset];
	[_timerView start];
	[_timerView update];
	
	_timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
		if (!self.paused) {
			self.timeLeft -= 1;
			[self.timerView setNeedsDisplay:YES];
			[self.timerView update];
			
			NSInteger minutes = floor(self.timeLeft / 60);
			NSInteger seconds = self.timeLeft - minutes * 60;
			
			[self.minutes setStringValue:[NSString stringWithFormat:@"%lu:%lu", minutes, seconds]];
		}
		
		// Time is up
		if (self.timeLeft < 0) {
			[self timeIsUp];
		}
		
		CGFloat progress = (CGFloat)self.timeLeft / (CGFloat)self.timeTotal;
		self.timerView.progress = progress;
	}];

	[self start];
}
- (void)start {
	_paused = NO;
	//[_pauseButton setTitle:@"||"];
	[_pauseButton setImage:[NSImage imageNamed:NSImageNameTouchBarPauseTemplate]];
}
- (IBAction)pause:(id)sender {
	_paused = !_paused;
	if (_paused) [_pauseButton setImage:[NSImage imageNamed:NSImageNameTouchBarPlayTemplate]]; else [_pauseButton setImage:[NSImage imageNamed:NSImageNameTouchBarPauseTemplate]];
}
- (void)reset {
	[self resetUI];
	
	_timeLeft = 0;
	
	[_timer invalidate];
	[_timerView reset];
	[_popover close];
}
- (void)resetUI {
	// Reset everything to default
	[_resetButton setHidden:YES];
	
	[_startButton setTitle:@"Start"];
	[_pauseButton setHidden:YES];
	[_label setHidden:NO];
	[_minutes setEnabled:YES];
	
	if (_timeTotal > 0) {
		[_minutes setStringValue:[NSString stringWithFormat:@"%lu", _timeTotal / 60]];
	} else {
		[_minutes setStringValue:@"25"];
	}
}
- (void)timeIsUp {
	[_timer invalidate];
	[_timerView finish];
	[self showAlert];
	
	[self resetUI];
}
- (void)showAlert {
	NSPopover *popover = [[NSPopover alloc] init];
	
	NSView *infoContentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
	NSViewController *infoViewController = [[NSViewController alloc] init];
	[infoViewController setView:infoContentView];
	popover.contentViewController = infoViewController;
	
	NSButton *buttonDismiss = [NSButton buttonWithTitle:@"✔︎" target:self action:@selector(dismiss)];
	NSButton *buttonRepeat = [NSButton buttonWithTitle:@"↻" target:self action:@selector(restart)];
	
	[buttonDismiss.cell setBordered:NO];
	[buttonDismiss setBordered:NO];
	
	[buttonRepeat.cell setBordered:NO];
	[buttonRepeat setBordered:NO];

	NSRect frame = buttonRepeat.frame;
	frame.origin.x = 35;
	[buttonRepeat setFrame:frame];
	
	[infoContentView addSubview:buttonDismiss];
	[infoContentView addSubview:buttonRepeat];
	
	
	[popover setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
	[popover setContentSize:NSMakeSize(80, frame.size.height)];
	[popover showRelativeToRect:self.timerView.frame ofView:self.timerView.window.contentView
				  preferredEdge:NSMinXEdge];
	_popover = popover;
}

- (void)dismiss {
	[_timerView reset];
	[_popover close];
}
- (void)restart {
	[_popover close];
	[self timerFor:self.timeTotal];
}

@end
