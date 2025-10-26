//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license


#ifdef ADHOC
#import <Sparkle/Sparkle.h>
#endif

#import <os/log.h>
#import <BeatParsing/BeatParsing.h>
#import <StoreKit/StoreKit.h>
#import <BeatCore/NSString+VersionNumber.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatPlugins/BeatPlugins.h>
#import <BeatFileExport/BeatFileExport.h>

#import "BeatAppDelegate.h"
#import "BeatAppDelegate+DarkMode.h"
#import "BeatAppDelegate+Backups.h"
#import "BeatAppDelegate+AdditionalViews.h"

#import "BeatNotifications.h"

#ifndef QUICKLOOK
#import "Beat-Swift.h"
#endif

#import "BeatTest.h"

#define APPNAME @"Beat"

@interface BeatAppDelegate () <BeatThemeDelegate>

@property (nonatomic) BeatNotifications *notifications;

// Some outlets for classes added in IB
@property (nonatomic) IBOutlet BeatPluginMenuManager *pluginMenuManager;
@property (nonatomic) IBOutlet BeatWebResources *resources;
@property (nonatomic) IBOutlet BeatSpellCheckingUtils *spellCheckingUtils;

@property (nonatomic) IBOutlet BeatTemplateMenuProvider *templateMenuProvider;

@property (nonatomic) BeatTest *tests;

#ifdef ADHOC
// Ad hoc distribution vector uses Sparkle to deliver updates
@property (nonatomic) IBOutlet SPUUpdater *updater;
@property (nonatomic) IBOutlet SPUStandardUserDriver *userDriver;
#endif

@property (nonatomic) IBOutlet NSMenuItem *checkForUpdatesItem;

@end

@implementation BeatAppDelegate

#define DEVELOPMENT NO
#define LATEST_VERSION_KEY @"Latest Version"

#pragma mark - Help

+(void)load {
	[super load];
}

- (instancetype) init {
	self = [super init];
	
	// Use these to reset any user defaults (for debugging purposes)
	//[NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
	//[NSUserDefaults.standardUserDefaults removeObjectForKey:@"AppleLanguages"];
	
	[self checkDarkMode];
	NSWindow.allowsAutomaticWindowTabbing = true;
	
	return self;
}

- (void)awakeFromNib
{
	NSLog(@"(beat) %@ / %@ - %@ distribution",
		  NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
		  NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],
		  BeatAppDelegate.distribution);
	
	// Setup (or remove) auto-update system and menu items
	[self setupUpdates];
	
	// Show welcome screen
	[self showLaunchScreen];
	
	// Populate plugin menu
	[self.pluginMenuManager setup];
	// Populate style menu
	[self.styleMenuManager setup];
}

+ (NSString*)distribution
{
#ifdef ADHOC
	return @"Ad Hoc";
#endif
#ifdef APPSTORE
	return @"App Store";
#endif
#ifdef ORGANIZATION
	return @"Academic";
#endif
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	if (@available(macOS 10.14, *)) {
		UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
		[center requestAuthorizationWithOptions:UNAuthorizationOptionBadge | UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError * _Nullable error) {
		}];
	}
		
#ifdef ADHOC
	// Run Sparkle if this is an ad hoc distribution
	if (self.updater.automaticallyChecksForUpdates) [self.updater checkForUpdatesInBackground];
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self setupDocumentOpenListener];

	// Show launch screen
	[self showLaunchScreen];
	
	// Lastly, open patch notes if the app was recently updated
	[self checkVersion];
	
	// Add to launch count
	NSInteger timesLaunched = [NSUserDefaults.standardUserDefaults integerForKey:@"LaunchCount"] + 1;
	[NSUserDefaults.standardUserDefaults setInteger:timesLaunched forKey:@"LaunchCount"];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
#ifdef ADHOC
	//[BeatDonationPlea nag];
#endif
}


#pragma mark - Window management

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	return !flag;
}


#pragma mark - Updates

- (void)setupUpdates
{
#ifdef ADHOC
	[self setupSparkle];
#else
	// Remove update/ad hoc related menu items
	[_checkForUpdatesItem.menu removeItem:_checkForUpdatesItem];
	_checkForUpdatesItem = nil;
#endif
}

#ifdef ADHOC
- (void)setupSparkle
{
	// Init Sparkle
	self.userDriver = [[SPUStandardUserDriver alloc] initWithHostBundle:NSBundle.mainBundle delegate:nil];
	self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:self.userDriver delegate:nil];
	
	// Start updater
	NSError *error;
	[self.updater startUpdater:&error];
	if (error) NSLog(@"Sparkle error: %@", error);
	
	// Add selector to check updates item
	_checkForUpdatesItem.action = @selector(checkForUpdates:);
}
#endif


#pragma mark - Updates

-(void)checkForUpdates:(id)sender
{
#ifdef ADHOC
	// Only allow this in ad hoc distribution
	[self.updater checkForUpdates];
#endif
}

-(void)checkVersion
{
	NSInteger latestVersion = [[NSUserDefaults.standardUserDefaults objectForKey:LATEST_VERSION_KEY] integerValue];
	NSInteger currentVersion = [[NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"] integerValue];
	
	// Show patch notes if it's the first time running Beat or if the app has been updated
	if (latestVersion == 0 || currentVersion > latestVersion) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%lu", currentVersion] forKey:LATEST_VERSION_KEY];
		[self.resources showPatchNotesWithSender:nil];
	}
}


#pragma mark - Handoff
/*
- (BOOL)application:(NSApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<NSUserActivityRestoring>> * _Nonnull))restorationHandler
{
	return false;
}
*/


#pragma mark - Generic methods for opening a plain-text file

- (id)newDocumentWithContents:(NSString*)string
{
	NSURL *tempURL = [BeatPaths urlForTemporaryFileWithPrefix:@"fountain"];
	NSError *error;
	
	[string writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	id document = [NSDocumentController.sharedDocumentController duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
	
	return document;
}

- (IBAction)newDocument:(id)sender
{
	[NSDocumentController.sharedDocumentController newDocument:sender];
}


#pragma mark - Create a file with rich text contents (attributed string)

/*
/// Unfortunately this requires some additional hacking.
- (id)newDocumentWithAttributedString:(NSAttributedString*)string
{
	NSURL* tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
	
	NSMutableAttributedString* result = string.mutableCopy;
	[string enumerateAttributesInRange:NSMakeRange(0, string.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		// First append the string
		NSString* s = [string.string substringWithRange:range];
		[result appendAttributedString:[NSAttributedString.alloc initWithString:s]];
		
		// Then append all Beat-related attributes
		for (NSString* key in attrs.allKeys) {
			if ([key rangeOfString:@"Beat"].location != 0) continue;
			id value = attrs[key];
			
			if (value != nil) [result addAttribute:key value:value range:range];
		}
	}];
	
	BeatDocumentSettings* docSettings = BeatDocumentSettings.new;
	[docSettings set:DocSettingRevisions as:<#(nonnull id)#>
}
*/


#pragma mark - Menu delegation

-(void)menuWillOpen:(NSMenu *)menu
{
	if (menu == _backupMenu) {
		[self addBackupMenuItemsTo:menu];
	}
}


#pragma mark - Show notifications

- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval
{
	if (!_notifications) _notifications = BeatNotifications.new;
	[_notifications showNotification:title body:body identifier:identifier oneTime:showOnce interval:interval];
}


#pragma mark - Supporting methods

/// This is here just to conform to theme manager delegate. Themes should be a part of the BeatCore framework, just saying.
- (NSURL*)appDataPath:(NSString*)subPath {
	return [BeatPaths appDataPath:subPath];
}


@end
