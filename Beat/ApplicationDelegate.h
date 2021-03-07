//
//  ApplicationDelegate.h
//  Beat
//
//  Copyright © 2019-2020 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "RecentFiles.h"

@interface ApplicationDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate, NSMenuDelegate>

@property (nonatomic) bool darkMode;
@property (nonatomic) bool forceLightMode;
@property (nonatomic) bool forceDarkMode;

// Plugin support
@property (weak) IBOutlet NSMenu *pluginMenu;

// Modifier for "pro" version, meaning the App Store edition.
// You could think that one can just change this byte to true in the open source version, but actually the "pro" stuff is just additional content and not really restricting any other functionality in the app, so it's no use.
@property (nonatomic) bool proMode;

- (IBAction)closeStartModal;
- (IBAction)showPatchNotes:(id)sender;

- (bool)isDark;
- (void)toggleDarkMode;
- (bool)isForcedLightMode;
- (bool)isForcedDarkMode;
- (bool)OSisDark;

- (void)showTemplate:(NSString*)name;

- (NSURL*)appDataPath:(NSString*)subPath;
- (void)newDocumentWithContents:(NSString*)string;

- (void)openURLInWebBrowser:(NSString*)urlString;

@end
