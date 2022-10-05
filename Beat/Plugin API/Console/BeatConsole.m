//
//  BeatConsole.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatConsole.h"
#import <Cocoa/Cocoa.h>
#import <os/log.h>

@interface BeatConsole ()
@property (nonatomic) NSPanel *console;
@property (nonatomic) NSTextView *consoleTextView;
@end

@implementation BeatConsole

+ (BeatConsole*)shared
{
	static BeatConsole* console;
	if (!console) {
		console = BeatConsole.new;
	}
	return console;
}

-(void)openConsole {
	if (!NSThread.isMainThread) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self createAndOpenConsoleWindow];
		});
	} else {
		[self createAndOpenConsoleWindow];
	}
}
-(void)createAndOpenConsoleWindow {
	// This is written very quickly on a train and is VERY hacky and shady. Works for now, though.
	if (!self.console) {
		NSArray *objects = [NSArray array];
		[NSBundle.mainBundle loadNibNamed:@"BeatConsole" owner:self.console topLevelObjects:&objects];
		self.console = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 450, 100) styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskHUDWindow | NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow backing:NSBackingStoreBuffered defer:NO];
		
		NSPanel *panel;
		for (id item in objects) { if ([item isKindOfClass:NSPanel.class]) panel = item; }
		self.console.contentView = panel.contentView;
		self.consoleTextView = [(NSScrollView*)self.console.contentView.subviews[0] documentView];
	}

	[self.console makeKeyAndOrderFront:nil];
}
-(void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName {
	if (!_console) return;
	
	NSString *consoleValue = [NSString stringWithFormat:@"%@: %@\n", pluginName, string];
	os_log(OS_LOG_DEFAULT, "[plugin] %@: %@", pluginName, string);
	
	// Ensure main thread
	if (!NSThread.isMainThread) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self logMessage:consoleValue];
		});
	} else {
		[self logMessage:consoleValue];
	}
}
- (void)logMessage:(NSString*)consoleValue {
	[self.consoleTextView.textStorage replaceCharactersInRange:NSMakeRange(self.consoleTextView.string.length, 0) withString:consoleValue];
	[self.consoleTextView.textStorage addAttribute:NSForegroundColorAttributeName value:NSColor.textColor range:(NSRange){ self.consoleTextView.string.length - consoleValue.length, consoleValue.length }];

	[self.consoleTextView.layoutManager ensureLayoutForTextContainer:self.consoleTextView.textContainer];
	self.consoleTextView.frame = [self.consoleTextView.layoutManager usedRectForTextContainer:self.consoleTextView.textContainer];
	
	// Get clip view
	NSClipView *clipView = self.consoleTextView.enclosingScrollView.contentView;

	// Calculate the y position by subtracting clip view height from total document height
	CGFloat scrollTo = self.consoleTextView.frame.size.height - clipView.frame.size.height;

	// Animate bounds
	[clipView setBoundsOrigin:NSMakePoint(0, scrollTo)];
}

-(void)clearConsole {
	if (!_console) return;
	
	[_consoleTextView.textStorage replaceCharactersInRange:(NSRange){0, _consoleTextView.string.length} withString:@""];
	[_consoleTextView setTextColor:NSColor.whiteColor];
}

@end
