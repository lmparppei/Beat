//
//  BeatEditorButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatEditorButton.h"
#import "BeatAppDelegate.h"
#import "BeatColors.h"

IB_DESIGNABLE
@interface BeatEditorButton ()
//@property (nonatomic) NSColor *offColor;
//@property (nonatomic) NSColor *onColor;
@end

@implementation BeatEditorButton

- (void)awakeFromNib {
	/*
	_offColor = NSColor.darkGrayColor;
	_onColor = NSColor.blackColor;
	[self updateTint];
	*/
	if (@available(macOS 10.14, *)) {
		if (_onOffButton) self.contentTintColor = [BeatColors color:@"blue"];
	}
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (void)layout {
	BeatAppDelegate *appDelegate = (BeatAppDelegate*)NSApp.delegate;
	NSImage *image = self.image;
	
	if (@available(macOS 10.14, *)) {
		if (appDelegate.isDark) [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
		else [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
	}
	
	[image setTemplate:YES];
	[super layout];
}

- (void)setState:(NSControlStateValue)state {
	[super setState:state];
	//[self updateTint];
}
/*
- (void)updateTint {
	[self.layer setBackgroundColor:[NSColor clearColor].CGColor];
	
	if (!self.layer) [self setWantsLayer:YES];
	if (!self.layer.mask) {
		NSImage *template = [self.image copy];
		[template setTemplate:YES];
		[self setImage:nil];
		CALayer *maskLayer = [CALayer layer];
		[maskLayer setContents:template];
		[maskLayer setFrame:CGRectMake(0, 0, self.frame.size.height, self.frame.size.height)];
		[self.layer setMask:maskLayer];
	}
	
	if (self.state == NSOnState) {
		self.layer.backgroundColor = self.onColor.CGColor;
	} else {
		self.layer.backgroundColor = self.offColor.CGColor;
	}
}
 */


@end
