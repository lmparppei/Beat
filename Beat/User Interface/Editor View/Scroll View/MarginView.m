//
//  MarginView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
//  This draws a "paper" view under BeatTextView using a CALayer

#import "MarginView.h"
#import "DynamicColor.h"
#import "ThemeManager.h"
#import <QuartzCore/QuartzCore.h>

#define WHITESPACE 120
#define SHADOW_WIDTH 20
#define SHADOW_OPACITY 0.0125

@interface MarginView ()
@property (nonatomic) CALayer *paper;
@property (weak) ThemeManager *themeManager;
@property (nonatomic) NSSize oldSize;
@end

@implementation MarginView

-(void)awakeFromNib {
	self.themeManager = ThemeManager.sharedManager;
}

- (void)viewWillDraw {
	self.wantsLayer = YES;
	
	CGFloat marginWidth = (_editor.inset - WHITESPACE) * self.editor.magnification;
	
	if (!_paper) {
		// Setup background
		_paper = CALayer.layer;
		_paper.frame = CGRectMake(marginWidth, -50, self.frame.size.width - marginWidth * 2, self.frame.size.height + 100);
		_paper.bounds = CGRectMake(0, 0, _paper.frame.size.width, _paper.frame.size.height);
		
		// CALayer doesn't read the effective color
		if (_editor.isDark) {
			self.paper.backgroundColor = _themeManager.backgroundColor.darkAquaColor.CGColor;
			self.layer.backgroundColor = _themeManager.marginColor.darkAquaColor.CGColor;
		}
		else {
			self.paper.backgroundColor = _themeManager.backgroundColor.aquaColor.CGColor;
			self.layer.backgroundColor = _themeManager.marginColor.aquaColor.CGColor;
		}
		
		_paper.masksToBounds = NO;
		_paper.shadowOpacity = .05;
		_paper.shadowColor = NSColor.blackColor.CGColor;
		_paper.shadowRadius = 20;
		
		[self.layer addSublayer:_paper];
	}
	
	[self updateBackground];
	
}

- (void)updateBackground {
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		
	// Set background paper size
	CGFloat documentWidth = (_editor.documentWidth + WHITESPACE * 2) * _editor.magnification;
	//CGFloat marginWidth = (_editor.inset - WHITESPACE) * _editor.magnification;
	CGFloat x = (self.frame.size.width - documentWidth) / 2;
	_paper.frame = CGRectMake(x, -50, documentWidth, self.frame.size.height + 100);
	_paper.bounds = CGRectMake(0, 0, _paper.frame.size.width, _paper.frame.size.height);
	
	// CALayer doesn't read the effective color
	if (_editor.isDark) {
		self.paper.backgroundColor = _themeManager.backgroundColor.darkAquaColor.CGColor;
		self.layer.backgroundColor = _themeManager.marginColor.darkAquaColor.CGColor;
	}
	else {
		self.paper.backgroundColor = _themeManager.backgroundColor.aquaColor.CGColor;
		self.layer.backgroundColor = _themeManager.marginColor.aquaColor.CGColor;
	}

	[CATransaction commit];
}

- (void)drawRect:(NSRect)dirtyRect {
	//[NSGraphicsContext saveGraphicsState];
    [super drawRect:dirtyRect];
	//[NSGraphicsContext restoreGraphicsState];
    /*
	 // Draw background (we have drawBackground se as NO, as otherwise the margins didn't work.)
	 // I can't get my head around this so let's just do the background manually.
	 [self.backgroundColor setFill];
	
	 NSRectFill(NSMakeRect(0, 0, self.frame.size.width, self.frame.size.height));
	 
	 // Draw margins if they don't fall outsid(e/ish) the viewport
	 if (self.frame.size.width > 800) {
		 [self.marginColor setFill];
		 
		 CGFloat marginWidth = (_insetWidth - WHITESPACE) * _magnificationLevel;
		 
		 if (marginWidth > 0) {
			 // Set margin boxes
			 NSRect marginLeft = NSMakeRect(0, 0, marginWidth, self.frame.size.height);
			 NSRect marginRight = NSMakeRect((self.frame.size.width - marginWidth), 0, marginWidth, self.frame.size.height);
			 
			 NSRect shadowLeft = (NSRect){ marginLeft.size.width - SHADOW_WIDTH, 0, SHADOW_WIDTH, marginLeft.size.height };
			 NSRect shadowRight = (NSRect){ marginRight.origin.x, 0, SHADOW_WIDTH, marginRight.size.height };
			 
			 NSRectFillUsingOperation(marginLeft, NSCompositingOperationSourceOver);
			 NSRectFillUsingOperation(marginRight, NSCompositingOperationSourceOver);
			 
			 NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:NSColor.clearColor endingColor:[NSColor.blackColor colorWithAlphaComponent:SHADOW_OPACITY]];
			 [gradient drawInRect:shadowLeft angle:0];
			 [gradient drawInRect:shadowRight angle:180];
			 
		 }
	 }
	 */
}
- (bool)isFullscreen {
	return (([self.window styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
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
