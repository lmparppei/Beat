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
#define MINIMUM_MARGIN 125

@interface MarginView ()
@property (nonatomic) CALayer *paper;
@property (weak) ThemeManager *themeManager;
@property (nonatomic) NSSize oldSize;
@end

@implementation MarginView

-(void)awakeFromNib
{
	self.themeManager = ThemeManager.sharedManager;
}

- (void)viewWillDraw
{
	self.wantsLayer = YES;
	CGFloat marginWidth = (_editor.getTextView.textContainerInset.width) * self.editor.magnification;
	
	if (!_paper) {
		// Setup background
		_paper = CALayer.layer;
		_paper.frame = CGRectMake(marginWidth, -50, self.frame.size.width - marginWidth * 2, self.frame.size.height + 100);
		_paper.bounds = CGRectMake(0, 0, _paper.frame.size.width, _paper.frame.size.height);
		
		// CALayer doesn't read the effective color
		if (_editor.isDark) {
			self.paper.backgroundColor = _themeManager.backgroundColor.darkColor.CGColor;
			self.layer.backgroundColor = _themeManager.marginColor.darkColor.CGColor;
		}
		else {
			self.paper.backgroundColor = _themeManager.backgroundColor.lightColor.CGColor;
			self.layer.backgroundColor = _themeManager.marginColor.lightColor.CGColor;
		}
		
		_paper.masksToBounds = NO;
		_paper.shadowOpacity = SHADOW_OPACITY;
		_paper.shadowColor = NSColor.blackColor.CGColor;
		_paper.shadowRadius = SHADOW_WIDTH;
		
		[self.layer addSublayer:_paper];
	}
	
	[self updateBackground];
	
}

- (void)updateBackground {
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
	
	// Hide margins if there's no room for them
	bool showMargins = (margin >= MINIMUM_MARGIN);
	
	// CALayer doesn't read the effective color
	if (_editor.isDark) {
		self.paper.backgroundColor = _themeManager.backgroundColor.darkColor.CGColor;
		self.layer.backgroundColor = showMargins ? _themeManager.marginColor.darkColor.CGColor : _themeManager.backgroundColor.darkColor.CGColor;
	}
	else {
		self.paper.backgroundColor = _themeManager.backgroundColor.lightColor.CGColor;
		self.layer.backgroundColor = showMargins ? _themeManager.marginColor.lightColor.CGColor : _themeManager.backgroundColor.lightColor.CGColor;
	}

	// Remove shadow if needed
	NSColor* mColor = _editor.isDark ? ThemeManager.sharedManager.marginColor.darkColor : ThemeManager.sharedManager.marginColor.lightColor;
	NSColor* bColor = _editor.isDark ? ThemeManager.sharedManager.backgroundColor.darkColor : ThemeManager.sharedManager.backgroundColor.lightColor;
	self.paper.shadowOpacity = (showMargins && ![mColor isEqualTo:bColor]) ? SHADOW_OPACITY : 0.0;
	
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
