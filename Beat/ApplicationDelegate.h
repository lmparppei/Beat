//
//  ApplicationDelegate.h
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license.

/*
 
 NOTE:
 Beat is released under GPL license, but there is an App Store version coming up / already available.
 The full _code_ and all its features are freely distributed, but the extra content (manual, templates, etc.)
 in the app store version are copyrighted and not distributed within the git.
 
 */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "RecentFiles.h"

@interface ApplicationDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate> {
}

@property (weak) IBOutlet NSWindow* startModal;
@property (weak) IBOutlet NSWindow* aboutModal;

@property (weak) IBOutlet WKWebView *manualView;
@property (weak) IBOutlet NSOutlineView* recentFiles;

@property (weak) IBOutlet NSWindow* acknowledgementsModal;
@property (weak) IBOutlet NSTextView* acknowledgementsTextView;

@property (weak) IBOutlet NSTextField* versionField;
@property (weak) IBOutlet NSTextField* aboutVersionField;
@property (weak) IBOutlet NSTextView* aboutText;

@property (weak) IBOutlet NSMenuItem *menuManual;
@property (weak) IBOutlet NSWindow *manualWindow;

@property (nonatomic) bool darkMode;
@property (nonatomic) bool forceLightMode;
@property (nonatomic) bool forceDarkMode;

// Modifier for "pro" version, meaning the App Store edition.
// You could think that one can just change this byte to true in the open source version, but actually the "pro" stuff is just additional content and not really restricting any other functionality in the app, so it's no use.
@property (nonatomic) bool proMode;

//@property (nonatomic) NSTextField * versionField;

- (IBAction)closeStartModal;
- (IBAction)showPatchNotes:(id)sender;

- (bool)isDark;
- (void)toggleDarkMode;
- (bool)isForcedLightMode;
- (bool)isForcedDarkMode;
- (bool)OSisDark;

@end
