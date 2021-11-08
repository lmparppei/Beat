//
//  BeatTimer.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTimer.h"
#import "BeatComparison.h"

#define BUTTON_DONE @"✔︎"
#define BUTTON_REPEAT @"↻"

@interface BeatTimer ()
@property (nonatomic) __block NSInteger timeLeft;
@property (nonatomic) __block NSInteger timeTotal;
@property (nonatomic) __block NSInteger timeOriginal;
@property (nonatomic) __block bool paused;
@property (nonatomic) __block bool done;
@property (nonatomic) NSPopover *popover;

// Store versions to perform check after timer runs out
@property (nonatomic) NSString *scriptAtStart;
@property (nonatomic) NSString *scriptNow;

@end

@implementation BeatTimer

- (void)showTimer {
	[_window beginSheet:_inputPanel completionHandler:nil];
}
- (IBAction)setTimer:(id)sender {
	// Check if timer is already running
	if ([_startButton.title isEqualToString:@"Reset"]) {
		_charactersTyped = 0;
		[self reset];
	} else {
		CGFloat seconds = [_minutes.stringValue floatValue] * 60.0;
		if (seconds == 0) seconds = 1;
		
		// Save original time
		_timeOriginal = 60 / seconds;
		
		// Save the script at start to allow for some statistics
		_charactersTyped = 0;
		if (self.delegate) _scriptAtStart = [NSString stringWithString:_delegate.getText];
				
		// Set timer
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
	[_timerView.animator setAlphaValue:1.0];
	
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
	// Time is up otherwise too.
	// Stop sexism and racism.
	
	[_timer invalidate];
	[_timerView finish];
	
	// Get string for comparison
	if (self.delegate) _scriptNow = [NSString stringWithString:_delegate.getText];
	
	[self showAlert];
	
	[self resetUI];
}
- (void)showAlert {
	// Don't allow duplicate popovers
	if (_popover.shown) [_popover close];
	
	// Create comparison report
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setAlignment:NSTextAlignmentCenter];

	NSMutableAttributedString *removals = [[NSMutableAttributedString alloc] initWithString:@""];
	if (self.delegate && _scriptAtStart.length > 0 && _scriptNow.length > 0) {
		BeatComparison *comparison = [[BeatComparison alloc] init];
		NSDictionary *changes = [comparison changeListFrom:_scriptAtStart to:_scriptNow];
		NSInteger numberOfRemovals = [(NSNumber*)changes[@"removed"] integerValue];
		
		NSAttributedString *strChangesMade = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu\n", numberOfRemovals] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:14] }];
		NSAttributedString *strChanges = [[NSAttributedString alloc] initWithString:@"characters erased" attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:9] }];
		
		[removals appendAttributedString:strChangesMade];
		[removals appendAttributedString:strChanges];
		[removals addAttributes:@{ NSParagraphStyleAttributeName: style } range:NSMakeRange(0, removals.string.length)];
	}
	
	NSMutableAttributedString *typed = [[NSMutableAttributedString alloc] initWithString:@""];
	NSAttributedString *strCharactersTyped = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu\n", _charactersTyped] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:14] }];
	NSAttributedString *strTyped = [[NSAttributedString alloc] initWithString:@"characters\ntyped" attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:9] }];
	[typed appendAttributedString:strCharactersTyped];
	[typed appendAttributedString:strTyped];
	[typed addAttributes:@{ NSParagraphStyleAttributeName: style } range:NSMakeRange(0, typed.string.length)];

	
	NSPopover *popover = [[NSPopover alloc] init];
	
	NSView *infoContentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 80, 80)]; // 80, 40
	NSViewController *infoViewController = [[NSViewController alloc] init];
	[infoViewController setView:infoContentView];
	popover.contentViewController = infoViewController;
		
	NSButton *buttonDismiss = [NSButton buttonWithTitle:BUTTON_DONE target:self action:@selector(dismiss)];
	NSButton *buttonRepeat = [NSButton buttonWithTitle:BUTTON_REPEAT target:self action:@selector(restart)];
	
	[buttonDismiss.cell setBordered:NO];
	[buttonDismiss setBordered:NO];
	
	[buttonRepeat.cell setBordered:NO];
	[buttonRepeat setBordered:NO];

	NSRect frame = buttonRepeat.frame;
	frame.origin.x = 28;
	[buttonRepeat setFrame:frame];
	
	[infoContentView addSubview:buttonDismiss];
	[infoContentView addSubview:buttonRepeat];
	
	CGFloat padding = 5;
	
	NSTextField *typedField = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, frame.size.height, 100, 50)];
	typedField.editable = NO;
	[typedField setAttributedStringValue:typed];
	typedField.drawsBackground = NO;
	typedField.alignment = NSTextAlignmentCenter;
	typedField.bordered = NO;
	typedField.frame = NSMakeRect(padding, frame.size.height, 100, 50);
	
	[infoContentView addSubview:typedField];
	
	CGFloat width = typedField.frame.size.width + padding * 2;
	CGFloat height = frame.size.height + typedField.frame.size.height + padding * 2;
	
	[popover setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
	[popover setContentSize:NSMakeSize(width, height)];
	[popover showRelativeToRect:self.timerView.frame ofView:self.timerView.window.contentView
				  preferredEdge:NSMinXEdge];
	_popover = popover;
}

- (bool)running {
	if (!self.paused && _timeLeft > 0) return YES;
	else return NO;
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
