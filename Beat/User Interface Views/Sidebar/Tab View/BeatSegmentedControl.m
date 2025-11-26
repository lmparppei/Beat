//
//  BeatSegmentedControl.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatEditorDelegate.h>
#import "BeatSegmentedControl.h"
#import "BeatSegmentedCell.h"
#import "BeatSidebarTabView.h"
#import "NSImage+ProportionalScaling.h"
//#import <BeatPlugins/BeatWidgetView.h>
#import <BeatPlugins/BeatPlugins.h>

@interface BeatSegmentedControl () <BeatWidgetViewTabView>
@property (nonatomic, weak) IBOutlet BeatWidgetView* widgetView;
@end

@implementation BeatSegmentedControl

static NSImage* widgetIcon;
static NSDictionary* segmentImages;
static NSDictionary* selectedSegmentImages;

- (void)awakeFromNib
{
	if (widgetIcon == nil) widgetIcon = [self imageForSegment:self.lastSegment];
		
	[self createSegmentImages];
	[self updateWidgetTabState];
	[self setSelectedSegment:0];
	
	/*
	// This is a little weird. For some reason Ventura doesn't render the segments correctly, so we need to fix it manually.
	if (@available(macOS 14.0, *)) {
		// Do nothing
	} else if (@available(macOS 13.0, *)) {
		// Forced dark appearance
		[self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
	} else {
		// On older systems, we'll tint the icons by hand
		[self createSegmentImages];
	}
	 */
}

- (void)createSegmentImages
{
	static dispatch_once_t once;

	dispatch_once(&once, ^
	{
		NSMutableDictionary* imgs = NSMutableDictionary.new;
		NSMutableDictionary* selImgs = NSMutableDictionary.new;
		
		for (NSInteger i=0; i<self.segmentCount; i++) {
			NSImage* segmentImage = [self imageForSegment:i];
			imgs[@(i)] = [segmentImage tintedImageWithSelection:false];
			selImgs[@(i)] = [segmentImage tintedImageWithSelection:true];
			
			[self setImage:imgs[@(i)] forSegment:i];
		}
		
		segmentImages = imgs;
		selectedSegmentImages = selImgs;
	});
}

- (NSInteger)lastSegment { return self.segmentCount-1; }

-(void)viewWillDraw
{
	[self updateBackground];
	[super viewWillDraw];
}

- (void)updateBackground
{
	bool dark = ((id<BeatDarknessDelegate>)NSApp.delegate).isDark;
	NSColor *bgColor = (dark) ? ThemeManager.sharedManager.outlineBackground.darkColor : ThemeManager.sharedManager.outlineBackground.lightColor;
	
	self.layer.backgroundColor = bgColor.CGColor;
}

- (bool)widgetsVisible
{
	return (self.widgetView.subviews.count > 0);
}

-(IBAction)selectTab:(id)sender
{
	if (!self.widgetsVisible && self.selectedSegment == self.segmentCount-1) return;
	
	NSTabViewItem* tabView = [self.tabView tabViewItemAtIndex:self.selectedSegment];
	[self.tabView selectTabViewItem:tabView];
}

- (void)setSelectedSegment:(NSInteger)selectedSegment
{
	// Don't allow selecting widget view when no widgets are visible
	if (selectedSegment == self.lastSegment && !self.widgetsVisible) return;
	
	//[self setSelectedSegment:selectedSegment animate:NO];
	[super setSelectedSegment:selectedSegment];
	[self selectTab:nil];
	
	[self updateSegmentImages];
}

- (void)updateSegmentImages
{
	for (NSInteger i=0; i<self.segmentCount; i++) {
		NSImage* img = (i == self.selectedSegment) ? selectedSegmentImages[@(i)] : segmentImages[@(i)];
		if (i == self.segmentCount-1 && !self.widgetsVisible) {
			img = nil;
		}
		
		[self setImage:img forSegment:i];
	}
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	self.selectedSegment = [tabView indexOfTabViewItem:tabViewItem];
}


- (void)updateWidgetTabState
{ 
	[self setImage:(self.widgetsVisible) ? widgetIcon : nil forSegment:self.lastSegment];
	[self setEnabled:(self.widgetsVisible) forSegment:self.lastSegment];
}

@end
/*
 
 I never felt as beautiful
 as when you told me I was beautiful
 your words have a tendency to reach deep within
 touching my soul, penetrating my skin
 
 you make my heart beat, steady as a clock
 your words touch as deep, and so does your cock
 your cock and your words, fills me with joy
 everything about you is perfect boy
 
 */
