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

/// Forces all views to redraw. Does NOT load colors from the theme, despite the weird method name.
/// - note: This method is NOT implemented by primary class, just appears so because it's inherited from `BeatEditorDelegate` definition. Objc selectors will sort this out.
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
	
	[self.textView setNeedsLayout:YES];
	[(BeatTextView*)self.textView redrawUI];
	[self.textView setNeedsDisplayInRect:self.textView.frame avoidAdditionalLayout:YES];
	
	// Update background layers
	[self.marginView updateBackground];
}

- (void)updateTheme
{
	ThemeManager* tm = ThemeManager.sharedManager;
	
	self.textView.marginColor = tm.marginColor;
	self.textScrollView.marginColor = tm.marginColor;
	// Because insertion point is a layer, it doesn't follow light/dark color in post-Sonoma (?)
	self.textView.insertionPointColor = (self.isDark) ? tm.caretColor.darkColor : tm.caretColor.lightColor;
	
	[self.textView setSelectedTextAttributes:@{
		NSBackgroundColorAttributeName: tm.selectionColor,
		NSForegroundColorAttributeName: tm.backgroundColor
	}];
				
	[self updateUIColors];
}

- (void)loadSelectedTheme:(bool)forAll
{
	NSArray* openDocuments;
	
	if (forAll) openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	else openDocuments = @[self];
	
	for (Document* doc in openDocuments) {
		[doc updateTheme];
	}
}



@end
