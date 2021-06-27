//
//  BDMCheckboxCell.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.4.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BDMCheckboxCell.h"
#import "BeatPluginManager.h"
#import <CoreImage/CoreImage.h>

#define DEFAULT_HEIGHT 50
#define DEFAULT_TEXT_HEIGHT 13

@interface BDMCheckboxCell ()
@property (weak) BeatPluginManager *pluginManager;
@end

@implementation BDMCheckboxCell

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)setSize {
	// Set default size
	NSRect frame = self.frame;
	frame.size.height = DEFAULT_HEIGHT;
	self.frame = frame;
	
	NSRect textFrame = _pluginText.frame;
	textFrame.size.height = DEFAULT_TEXT_HEIGHT;

	_pluginText.preferredMaxLayoutWidth = _pluginText.frame.size.width;
	[_pluginText invalidateIntrinsicContentSize];
	[self layoutSubtreeIfNeeded];
	
	if (_pluginText.frame.size.height < _pluginText.intrinsicContentSize.height) {
		CGFloat heightDiff = _pluginText.intrinsicContentSize.height - _pluginText.frame.size.height;
		
		textFrame = _pluginText.frame;
		frame = self.frame;
		
		textFrame.size.height += heightDiff;
		frame.size.height += heightDiff;
		
		self.frame = frame;
		_pluginText.frame = textFrame;
		
		_rowHeight = self.frame.size.height;
	} else {
		_rowHeight = self.frame.size.height;
	}
}

-(void)viewWillDraw {
	if (_localURL) {
		// Plugin is installed
		[_pluginName setTextColor:NSColor.labelColor];
		[_downloadButton setHidden:YES];
		[_checkbox setHidden:NO];
	} else {
		// Plugin is downloadable
		[_pluginName setTextColor:NSColor.secondaryLabelColor];
		[_downloadButton setHidden:NO];
		[_checkbox setHidden:YES];
	}
	
	if (_updateAvailable) {
		NSLog(@"Check: update available for %@", _name);
		[_downloadButton setHidden:NO];
		[_downloadButton setTitle:@"Update"];
		
		self.wantsLayer = YES;
		self.layer.backgroundColor = NSColor.darkGrayColor.CGColor;
	} else {
		[_downloadButton setTitle:@"Download"];
		
		self.wantsLayer = NO;
		self.layer.backgroundColor = NSColor.clearColor.CGColor;
	}
	
	if (_enabled) [_checkbox setState:NSOnState]; else [_checkbox setState:NSOffState];
	[_pluginName setStringValue:_name];
	(_info) ? [_pluginText setStringValue:[_info stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]] : [_pluginText setStringValue:@""];
		
	
	//NSString *copyrightAndVersion = [NSString stringWithFormat:@"%@ — %@", (_version) ? _version : @"", (_copyright) ? _copyright : @""];
	
}

- (IBAction)download:(id)sender {
	if (!_pluginManager) _pluginManager = [BeatPluginManager sharedManager];
	[_pluginManager downloadPlugin:_name sender:self];
}

- (void)downloadComplete {
	[_pluginName setTextColor:NSColor.labelColor];
	[_checkbox setHidden:NO];
	[_downloadButton setTitle:@"Success"];
	[_downloadButton setEnabled:NO];
}

- (IBAction)togglePlugin:(id)sender {
	if (!_pluginManager) _pluginManager = [BeatPluginManager sharedManager];
	
	NSButton *checkBox = (NSButton*)sender;
	if (checkBox.state == NSOnState) {
		NSLog(@"enable");
		[_pluginManager enablePlugin:self.name];
	} else {
		[_pluginManager disablePlugin:self.name];
	}
}

- (NSImage*)buttonBackground:(NSColor*)color size:(CGSize)size {
	size = NSMakeSize(200, 200);
	NSImage *image = [[NSImage alloc] initWithSize:size];
	[image lockFocus];
	[color drawSwatchInRect:(NSRect){ 0, 0, size.width, size.height }];
	[image unlockFocus];
	return image;
}

@end
/*
 
 nää langat on sidottu solmuun
 solmut on solmittu uudestaan
 ja perään sidottu vielä painoo
 ja heitetty syvään kaivoon.
 
 */
