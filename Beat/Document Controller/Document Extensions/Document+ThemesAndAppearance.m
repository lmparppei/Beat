//
//  Document+ThemesAndAppearance.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+ThemesAndAppearance.h"
#import "BeatAppDelegate.h"
#import "ColorView.h"
#import <BeatThemes/BeatThemes.h>
#import "ScrollView.h"
#import "MarginView.h"
#import "BeatSegmentedControl.h"
#import "BeatTextView.h"
#import "BeatOutlineView.h"

@implementation Document (ThemesAndAppearance)


#pragma mark - Themes & UI

- (IBAction)toggleDarkMode:(id)sender
{
	BeatAppDelegate* delegate = (BeatAppDelegate*)NSApplication.sharedApplication.delegate;
	[delegate toggleDarkMode];
}

- (void)didChangeAppearance
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self updateUIColors];
	});
}

- (void)updateUIColors
{
	if (self.documentWindow.frame.size.height == 0 || self.documentWindow.frame.size.width == 0) return;

	if (@available(macOS 10.14, *)) {
		// Force the whole window into dark mode if possible.
		// This redraws everything by default.
		self.documentWindow.appearance = [NSAppearance appearanceNamed:(self.isDark) ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
		self.documentWindow.viewsNeedDisplay = true;
	} else {
		// Else, we need to force everything to redraw, in a very clunky way.
		// Please god, if you exist, give me the courage to drop support for macOS 10.13
		[self.documentWindow setViewsNeedDisplay:true];
		
		[self.documentWindow.contentView setNeedsDisplay:true];
		[self.backgroundView setNeedsDisplay:true];
		[self.textScrollView setNeedsDisplay:true];
		[self.marginView setNeedsDisplay:true];
		
		[self.textScrollView layoutButtons];
		
		[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
		
		[self.textView drawViewBackgroundInRect:self.textView.bounds];
		
		self.textView.needsDisplay = true;
		self.textView.needsLayout = true;
	}
	
	if (self.sidebarVisible) {
		self.outlineBackgroundView.needsDisplay = true;
		
		self.sideBarTabs.needsDisplay = true;
		self.sideBarTabs.needsLayout = true;
		
		self.sideBarTabControl.needsDisplay = true;
		self.sideBarTabControl.needsLayout = true;
		
		[self.outlineView reloadOutline];
	}
	
	ThemeManager* tm = ThemeManager.sharedManager;
	
	// Set global background
	NSColor *bgColor = ([self isDark]) ? tm.outlineBackground.darkColor : tm.outlineBackground.lightColor;
	self.backgroundView.layer.backgroundColor = bgColor.CGColor;
	
	[self.textScrollView layoutButtons];
	[self.documentWindow setViewsNeedDisplay:true];
	[(BeatTextView*)self.textView redrawUI];

	// Update background layers
	[self.marginView updateBackground];
}

- (void)updateTheme
{
	[self setThemeFor:self setTextColor:NO];
}

- (void)setThemeFor:(Document*)doc setTextColor:(bool)setTextColor
{
	if (!doc) doc = self;
	
	ThemeManager* tm = ThemeManager.sharedManager;
	BeatTextView* textView = (BeatTextView*)doc.textView;
	
	textView.marginColor = tm.marginColor;
	textView.textColor = tm.textColor;
	textView.insertionPointColor = tm.caretColor;
	doc.textScrollView.marginColor = tm.marginColor;
	
	[doc.textView setSelectedTextAttributes:@{
		NSBackgroundColorAttributeName: tm.selectionColor,
		NSForegroundColorAttributeName: tm.backgroundColor
	}];
	
	if (setTextColor) {
		[doc.textView setTextColor:tm.textColor];
	} else {
		[self.textView setNeedsLayout:YES];
		[self.textView setNeedsDisplayInRect:self.textView.frame avoidAdditionalLayout:YES];
	}
			
	[doc updateUIColors];
	
	[doc.documentWindow setViewsNeedDisplay:YES];
	[doc.textView setNeedsDisplay:YES];
}

- (void)loadSelectedTheme:(bool)forAll
{
	NSArray* openDocuments;
	
	if (forAll) openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	else openDocuments = @[self];
	
	for (Document* doc in openDocuments) {
		[self setThemeFor:doc setTextColor:YES];
	}
}



@end
