//
//  MarginView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
//  This draws a "paper" view under BeatTextView using a CALayer

#import "MarginView.h"
#import <BeatThemes/BeatThemes.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatDynamicColor/BeatDynamicColor.h>

#define SHADOW_WIDTH 20
#define SHADOW_OPACITY 0.05
#define MINIMUM_MARGIN 115

@interface MarginView ()
@property (nonatomic) CALayer *paper;
@property (weak) ThemeManager *themeManager;
@property (nonatomic) NSSize oldSize;
@end

@implementation MarginView

-(void)awakeFromNib
{
	self.wantsLayer = YES;
	self.themeManager = ThemeManager.sharedManager;
	
	if (_paper == nil) {
		// Setup background
		_paper = CALayer.layer;
		
		_paper.masksToBounds = NO;
		_paper.shadowOpacity = SHADOW_OPACITY;
		_paper.shadowColor = NSColor.blackColor.CGColor;
		_paper.shadowRadius = SHADOW_WIDTH;
		
		[self.layer addSublayer:_paper];
		
		[self updateBackground];
	}
}

- (void)viewWillDraw
{
	[self updateBackground];
}

- (void)updateBackground
{
	// This shouldn't happen but just to be sure
	if (!_paper || !_editor) return;
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// Set background paper size
	CGFloat documentWidth = (_editor.documentWidth) * _editor.magnification;
	CGFloat margin = (self.frame.size.width - documentWidth) / 2;
	CGFloat x = margin;
	if (x < 0) x = 0.0;
	
	if (self.editor.getTextView.enclosingScrollView.rulersVisible) {
		x += self.editor.getTextView.enclosingScrollView.verticalRulerView.frame.size.width;
	}
	
	_paper.frame = CGRectMake(x, -50, documentWidth, self.frame.size.height + 100);
	_paper.bounds = CGRectMake(0, 0, _paper.frame.size.width, _paper.frame.size.height);
	
	// CALayer doesn't read the effective color, we need to do it manually
	NSColor* marginColor = _editor.isDark ? ThemeManager.sharedManager.marginColor.darkColor : ThemeManager.sharedManager.marginColor.lightColor;
	NSColor* bgColor = _editor.isDark ? ThemeManager.sharedManager.backgroundColor.darkColor : ThemeManager.sharedManager.backgroundColor.lightColor;
	
	// Hide margins if there's no room for them
	bool showMargins = (margin >= MINIMUM_MARGIN);
	if (!showMargins) marginColor = bgColor;
	
	self.paper.backgroundColor = bgColor.CGColor;
	self.layer.backgroundColor = marginColor.CGColor;
		
	// Remove shadow if needed
	self.paper.shadowOpacity = (showMargins && ![marginColor isEqualTo:bgColor]) ? SHADOW_OPACITY : 0.0;
	
	[CATransaction commit];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (bool)isFullscreen {
	return ((self.window.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

@end
/*
 
 kun mä kasvan isoksi
 haluan puutarhan
 ja pienen veneen
 
 istutan metsän talon ympärille
 tutustun sen eläimiin
 ja yritän oppia niiltä jotain
 
 kuten piiloutumisen taidon
 tai no sen mä opin
 jo lapsena jossakin
 
 */
