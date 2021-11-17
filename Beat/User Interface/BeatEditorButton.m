//
//  BeatEditorButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatEditorButton.h"
#import "BeatAppDelegate.h"
#import "BeatColors.h"
#import "ThemeManager.h"

IB_DESIGNABLE
@interface BeatEditorButton ()
//@property (nonatomic) NSColor *offColor;
//@property (nonatomic) NSColor *onColor;
@end

@implementation BeatEditorButton

- (void)awakeFromNib {
	if (@available(macOS 10.14, *)) {
		if (_onOffButton) {
			self.contentTintColor = NSColor.controlAccentColor;
			//self.contentTintColor = [BeatColors color:@"blue"];
		}
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
}

@end
/*
 
 mä tarviin
 nälkäisen pedon
 jota ruokkia
 
 mä tarviin
 eläimen
 joka nuolee
 mun sormia
 
 */
