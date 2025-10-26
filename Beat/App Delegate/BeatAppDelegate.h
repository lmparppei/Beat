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

typedef enum : NSUInteger {
	NoForcedAppearance = 0,
	ForcedDarkAppearance,
	ForcedLightAppearance
} BeatForcedAppearance;

@class BeatStyleMenuManager;
@class BeatBrowserView;
@class BeatPreferencesPanel;
@class BeatAboutScreen;
@class BeatPluginLibrary;
@class BeatEpisodePrinter;

@interface BeatAppDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate>

@property (nonatomic) bool darkMode;
@property (nonatomic) BeatForcedAppearance forcedAppearance;


@property (nonatomic) IBOutlet BeatStyleMenuManager *styleMenuManager;

/// Backup versions
@property (nonatomic, weak) IBOutlet NSMenu *backupMenu;
@property (nonatomic, weak) IBOutlet NSMenu *revertMenu;

@property (nonatomic, weak) IBOutlet NSMenu *pluginMenu;
@property (nonatomic, weak) IBOutlet NSMenu *exportMenu;
@property (nonatomic, weak) IBOutlet NSMenu *importMenu;


#pragma mark - Retained views

@property (nonatomic) NSWindow *welcomeWindow;
@property (nonatomic) BeatBrowserView *browser;
@property (nonatomic) BeatPreferencesPanel *preferencesPanel;
@property (nonatomic) BeatAboutScreen *about;
@property (nonatomic) BeatPluginLibrary *pluginLibrary;
@property (nonatomic) BeatEpisodePrinter *episodePrinter;


#pragma mark - Retained views

+ (NSString*)distribution;

- (NSURL*)appDataPath:(NSString*)subPath;
- (id)newDocumentWithContents:(NSString*)string;

- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval;

@end
