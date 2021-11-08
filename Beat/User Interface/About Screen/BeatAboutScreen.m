//
//  BeatAboutScreen.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAboutScreen.h"

@interface BeatAboutScreen ()
@property (weak) IBOutlet NSTextField *versionField;
@end

@implementation BeatAboutScreen

- (instancetype)init {
	return [super initWithWindowNibName:@"BeatAboutScreen" owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
	version = [version stringByAppendingFormat:@"\nBuild %@", NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
	_versionField.stringValue = [NSString stringWithFormat:@"Version %@", version];
}
- (void)show {
	[self.window setFrame:NSMakeRect(
									 (NSScreen.mainScreen.frame.size.width - self.window.frame.size.width) / 2,
									 (NSScreen.mainScreen.frame.size.height - self.window.frame.size.height) / 2,
									 self.window.frame.size.width, self.window.frame.size.height
									 )
						 display:YES];
	
	[self.window setIsVisible:true];
	[self showWindow:self.window];
	[self.window makeKeyAndOrderFront:self];
}
- (IBAction)showAcknowledgements:(id)sender {
	NSURL * url = [NSBundle.mainBundle URLForResource:@"Credits" withExtension:@"pdf"];
	[NSWorkspace.sharedWorkspace openURL:url];
}

@end
