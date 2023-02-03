//
//  BeatEditorButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
//  Buttons at the top of the editor

#import <BeatThemes/BeatThemes.h>
#import "BeatEditorButton.h"
#import "BeatAppDelegate.h"
#import <BeatCore/BeatColors.h>


IB_DESIGNABLE
@interface BeatEditorButton ()
@end

@implementation BeatEditorButton

- (void)awakeFromNib {
	if (@available(macOS 10.14, *)) {
		if (_onOffButton) {
			self.contentTintColor = NSColor.controlAccentColor;
		}
	}
	
	[self.image setTemplate:YES];
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (void)layout {
	[self updateAppearance];
	[super layout];
}

-(void)updateAppearance {
	if (@available(macOS 10.14, *)) {
		BeatAppDelegate *appDelegate = (BeatAppDelegate*)NSApp.delegate;
		if (appDelegate.isDark) [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
		else [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
	}
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
