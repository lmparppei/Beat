//
//  ApplicationDelegate.h
//  Beat
//
//  Copyright © 2019-2020 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <UserNotifications/UserNotifications.h>

@interface BeatAppDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate>

@property (nonatomic) bool darkMode;
@property (nonatomic) bool forceLightMode;
@property (nonatomic) bool forceDarkMode;

/// Backup versions
@property (nonatomic, weak) IBOutlet NSMenu *backupMenu;
@property (nonatomic, weak) IBOutlet NSMenu *revertMenu;

@property (nonatomic, weak) IBOutlet NSMenu *pluginMenu;
@property (nonatomic, weak) IBOutlet NSMenu *exportMenu;
@property (nonatomic, weak) IBOutlet NSMenu *importMenu;

/// Returns `true` when the app is running in dark mode – either simulated (10.13) or real (10.14+)
- (bool)isDark;
- (void)toggleDarkMode;
/// Returns `true` when the OS is set to dark mode
- (bool)OSisDark;

/// Opens a template file with the given name
- (void)showTemplate:(NSString*)name;

+ (NSURL*)appDataPath:(NSString*)subPath;
- (NSURL*)appDataPath:(NSString*)subPath;
- (NSString*)pathForTemporaryFileWithPrefix:(NSString *)prefix;
- (id)newDocumentWithContents:(NSString*)string;

- (IBAction)openPluginLibrary:(id)sender;
- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval;

/// Opens tutorial
- (IBAction)openTutorial:(id)sender;

/// Opens template menu
- (void)showTemplates;

@end
