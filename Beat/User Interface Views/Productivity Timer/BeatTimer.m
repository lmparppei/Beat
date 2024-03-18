//
//  BeatTimer.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTimer.h"
#import "BeatComparison.h"
#import <BeatCore/BeatLocalization.h>
#import "Beat-Swift.h"

#define BUTTON_DONE @"✔︎"
#define BUTTON_REPEAT @"↻"

@interface BeatTimer () <BeatTimerWindowDelegate>

@property (nonatomic) NSPopover *popover;

@property (nonatomic) BeatTimerWindow *timerPanel;

// Store versions to perform check after timer runs out
@property (nonatomic) NSString *scriptAtStart;
@property (nonatomic) NSString *scriptNow;

@end

@implementation BeatTimer

- (IBAction)showTimerSettings:(id)sender
{
	[self showTimer];
}

- (void)showTimer {
	self.timerPanel = BeatTimerWindow.new;
	self.timerPanel.timerDelegate = self;
	
	[_window beginSheet:self.timerPanel.window completionHandler:^(NSModalResponse returnCode) {
		self.timerPanel = nil;
	}];
}

- (void)timerFor:(NSInteger)seconds {
	_done = NO;
	
	_timerView.hidden = false;
	_timerView.animator.alphaValue = 1.0;
	
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
						
			// Set input panel value (if it's visible)
			[self updateTimerPanel];
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
}

- (void)pause {
	_paused = !_paused;
}

- (void)reset {
	_timeLeft = 0;
	
	[_timer invalidate];
	[_timerView reset];
	[_popover close];
}

- (void)updateTimerPanel {
	NSInteger minutes = floor(self.timeLeft / 60);
	NSInteger seconds = self.timeLeft - minutes * 60;

	self.timerPanel.minutes.stringValue = [NSString stringWithFormat:@"%lu:%lu", minutes, seconds];
}

- (void)timeIsUp {
	// Time is up otherwise too.
	// Stop sexism and racism.
	
	[_timer invalidate];
	[_timerView finish];
	
	// Get string for comparison
	if (self.delegate) _scriptNow = [NSString stringWithString:_delegate.text];
	
	[self showAlert];
}
- (void)showAlert {
	// Don't allow duplicate popovers
	if (_popover.shown) [_popover close];
	
	// Create comparison report
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setAlignment:NSTextAlignmentCenter];

	NSMutableAttributedString *removals = [[NSMutableAttributedString alloc] initWithString:@""];
	if (self.delegate && _scriptAtStart.length > 0 && _scriptNow.length > 0) {
		BeatComparison *comparison = BeatComparison.new;
		NSDictionary *changes = [comparison changeListFrom:_scriptAtStart to:_scriptNow];
		NSInteger numberOfRemovals = [(NSNumber*)changes[@"removed"] integerValue];
		
		NSAttributedString *strChangesMade = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu\n", numberOfRemovals] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:14] }];
		NSAttributedString *strChanges = [[NSAttributedString alloc] initWithString:[BeatLocalization localizedStringForKey:@"timer.charactersRemoved"] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:9] }];
		
		[removals appendAttributedString:strChangesMade];
		[removals appendAttributedString:strChanges];
		[removals addAttributes:@{ NSParagraphStyleAttributeName: style } range:NSMakeRange(0, removals.string.length)];
	}
	
	NSMutableAttributedString *typed = [[NSMutableAttributedString alloc] initWithString:@""];
	NSAttributedString *strCharactersTyped = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu\n", _charactersTyped] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:14] }];
	NSAttributedString *strTyped = [[NSAttributedString alloc] initWithString:[BeatLocalization localizedStringForKey:@"timer.charactersRemoved"] attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:9] }];
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
