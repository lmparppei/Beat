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
#import "RecentFiles.h"
#import "BeatFileImport.h"
#import "BeatBrowserView.h"
#import "BeatAboutScreen.h"
#import "BeatEpisodePrinter.h"
#import "BeatNotifications.h"
#import "BeatModalInput.h"
#import "Document.h"
#import "BeatPreferencesPanel.h"
#import "BeatPluginLibrary.h"

#ifndef QUICKLOOK
#import "Beat-Swift.h"
#endif

#import "BeatTest.h"

#define APPNAME @"Beat"

@interface BeatAppDelegate () <BeatThemeDelegate>

@property (nonatomic) IBOutlet NSMenuItem *menuManual;

@property (nonatomic) IBOutlet BeatPluginMenuManager *pluginMenuManager;

@property (nonatomic) BeatNotifications *notifications;

@property (nonatomic) NSWindow *welcomeWindow;
@property (nonatomic) BeatBrowserView *browser;
@property (nonatomic) BeatPreferencesPanel *preferencesPanel;
@property (nonatomic) BeatAboutScreen *about;

// New plugin library
@property (nonatomic) BeatPluginLibrary *pluginLibrary;

@property (nonatomic) BeatEpisodePrinter *episodePrinter;

@property (nonatomic) BeatTest *tests;

@property (nonatomic) IBOutlet BeatWebResources *resources;
@property (nonatomic) IBOutlet BeatSpellCheckingUtils *spellCheckingUtils;

@property (nonatomic) IBOutlet BeatTemplateMenuProvider *templateMenuProvider;

#ifdef ADHOC
// Ad hoc distribution vector uses Sparkle to deliver updates
@property (nonatomic) IBOutlet SPUUpdater *updater;
@property (nonatomic) IBOutlet SPUStandardUserDriver *userDriver;
#endif

@property (nonatomic) IBOutlet NSMenuItem *checkForUpdatesItem;
@property (nonatomic) IBOutlet NSMenuItem *enterLicenseKeyItem;

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

- (void)awakeFromNib {
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

- (void)setupUpdates
{
	bool showCheckUpdates = false;
	NSString* release = BeatAppDelegate.distribution;
#ifdef ADHOC
	showCheckUpdates = true;
	[self setupSparkle];
#endif
	
	NSLog(@"(beat) %@ / %@ - %@ distribution",
		  NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
		  NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],
		  release);
	
	if (!showCheckUpdates) {
		// Remove update/ad hoc related menu items
		[_checkForUpdatesItem.menu removeItem:_checkForUpdatesItem];
		[_enterLicenseKeyItem.menu removeItem:_enterLicenseKeyItem];
		
		_checkForUpdatesItem = nil;
	}
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	if (@available(macOS 10.14, *)) {
		UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
		[center requestAuthorizationWithOptions:UNAuthorizationOptionBadge | UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError * _Nullable error) {
		}];
	}
	
#ifdef ADHOC
	// Run Sparkle if this is an ad hoc distribution
	//if (self.updater.) [self.updater checkForUpdatesInBackground];
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
	[BeatDonationPlea nag];
#endif
}


#pragma mark - Updates

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


#pragma mark - Donations

- (IBAction)enterLicenseKey:(id)sender
{
	[BeatAdhocLicenseManager enterLicenseKey];
}



#pragma mark - Updates

-(void)checkForUpdates:(id)sender {
#ifdef ADHOC
	// Only allow this in ad hoc distribution
	[self.updater checkForUpdates];
#endif
}

-(void)checkVersion {
	NSInteger latestVersion = [[[NSUserDefaults standardUserDefaults] objectForKey:LATEST_VERSION_KEY] integerValue];
	NSInteger currentVersion = [[NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"] integerValue];
	
	// Show patch notes if it's the first time running Beat or if the app has been updated
	if (latestVersion == 0 || currentVersion > latestVersion) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%lu", currentVersion] forKey:LATEST_VERSION_KEY];
		[self.resources showPatchNotesWithSender:nil];
	}
}

-(void)setupDocumentOpenListener {
	// Let's close the welcome screen if any sort of document has been opened
	[NSNotificationCenter.defaultCenter addObserverForName:@"Document open" object:nil queue:nil usingBlock:^(NSNotification *note) {
		[self closeLaunchScreen];
	}];
	
	// Show modal if all documents were closed
	[NSNotificationCenter.defaultCenter addObserverForName:@"Document close" object:nil queue:nil usingBlock:^(NSNotification *note) {
		NSArray* openDocuments = NSApplication.sharedApplication.orderedDocuments;
		
		if (openDocuments.count == 0 && !self.welcomeWindow) {
			[self showLaunchScreen];
		}
		
#ifdef APPSTORE
		[self requestAppReview];
#endif
	}];
}

- (void)requestAppReview
{
	// The user has either clicked that they never want to review the app
	bool dontShowReviewPrompt = [NSUserDefaults.standardUserDefaults boolForKey:@"DontAskForReview"];
	if (dontShowReviewPrompt) return;
	
	// So, we'll see if the user has launched the app at least 50 times before requesting a review,
	// and _never_ again for the same version.
	NSInteger timesLaunched = [NSUserDefaults.standardUserDefaults integerForKey:@"LaunchCount"];
	NSString *lastVersionPrompted = [NSUserDefaults.standardUserDefaults valueForKey:@"LastVersionPromptedForReview"];
	NSString *currentVersion = [NSBundle.mainBundle.infoDictionary valueForKey:(NSString*)kCFBundleVersionKey];
	
	if (timesLaunched  % 51 == 50 && ![currentVersion isEqualToString:lastVersionPrompted]) {
		[NSUserDefaults.standardUserDefaults setValue:currentVersion forKey:@"LastVersionPromptedForReview"];
		
		if (@available(macOS 10.14, *)) [SKStoreReviewController requestReview];
	}
	
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}


#pragma mark - Autosave Recovery

- (void)checkAutosavedFiles {
	// We will run this operation in another thread, so that the app can start and opening recovered documents won't mess up any other logic built into the app.
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
		__block NSFileManager *fileManager = NSFileManager.defaultManager;
		
		NSString *appName = [NSBundle.mainBundle.infoDictionary objectForKey:(id)kCFBundleNameKey];
		NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString* appSupportDir = [searchPaths firstObject];
		appSupportDir = [appSupportDir stringByAppendingPathComponent:appName];
		appSupportDir = [appSupportDir stringByAppendingPathComponent:@"Autosave"];
		
		NSArray *files = [fileManager contentsOfDirectoryAtPath:appSupportDir error:nil];
		
		for (NSString *file in files) {
			if (![file.pathExtension isEqualToString:@"fountain"]) continue;
			
			__block NSString *filename = [NSString stringWithString:file];
			
			dispatch_async(dispatch_get_main_queue(), ^(void){
				
				NSAlert *alert = NSAlert.new;
				alert.messageText = [NSString stringWithFormat:@"%@", filename];
				alert.informativeText = @"An unsaved script was found. Do you want to open the latest autosaved version of this file?";
				[alert addButtonWithTitle:@"Open"];
				[alert addButtonWithTitle:@"Cancel"];

				NSModalResponse response = [alert runModal];

				if (response == NSAlertFirstButtonReturn) {
					NSString *contents = [NSString stringWithContentsOfFile:[appSupportDir stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
					[self newDocumentWithContents:contents];
				} else {
					[self deleteAutosaveFile:[appSupportDir stringByAppendingPathComponent:filename]];
				}
				
			});
		}
	});
}

- (void)deleteAutosaveFile:(NSString*)filename {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	@try {
		[fileManager removeItemAtPath:filename error:nil];
	} @catch (NSException *exception) {
		NSAlert *alert = [NSAlert.alloc init];
		alert.messageText = [NSString stringWithFormat:@"Error removing autosave file %@", filename];
		alert.informativeText = @"Beat doesn't have write permissions to access its Application Support folder. You need to remove the autosave file manually to avoid seeing this error in the future.\n\n\
		In Finder, press cmd-shift-G and type in ~/Library/Application Support/Beat/Autosave/ and delete any files in that folder. Sorry for any inconvenience.";
		alert.alertStyle = NSAlertStyleWarning;
		[alert runModal];
	} @finally {
	}
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	if (flag) return NO; else return YES;
}


#pragma mark - Dark mode stuff

// At all times, we have to check if OS is set to dark AND if the user has forced either mode
// This is horribly dated, but seems to work ---- for now.
// It's here because I'm trying to keep up support for macOS 10.13.

-(void)checkDarkMode {
	_darkMode = [BeatUserDefaults.sharedDefaults getBool:BeatSettingDarkMode];
	
	// If the OS is set to dark mode, we'll force it
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = NSAppearance.currentAppearance ?: NSApp.effectiveAppearance;
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			if (_darkMode == false) _forceLightMode = YES;
		} else {
			if (_darkMode) _forceDarkMode = YES;
		}
	}
}

- (bool)isDark {
	if ([self OSisDark]) {
		// OS in dark mode
		return !_forceLightMode;
	} else {
		// OS in light mode
		return _forceDarkMode;
	}
}

- (bool)OSisDark {
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSApp effectiveAppearance];
		if (!appearance) appearance = [NSAppearance currentAppearance];
		
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			return YES;
		}
	}
	return NO;
}

- (void)toggleDarkMode {
	_darkMode = ![self isDark];
	
	// OS is in dark mode, so we need to force the light mode
	if ([self OSisDark]) {
		if (!_darkMode) _forceLightMode = YES;
		else _forceLightMode = NO;
	}
	// And vice versa
	else if (![self OSisDark]) {
		if (_darkMode) _forceDarkMode = YES;
		else _forceDarkMode = NO;
	}
	
	[BeatUserDefaults.sharedDefaults saveBool:_darkMode forKey:BeatSettingDarkMode];
	
	NSArray* openDocuments = NSDocumentController.sharedDocumentController.documents;
	for (Document* doc in openDocuments) {
		[doc updateUIColors];
	}
}

#pragma mark - Tutorial and templates

- (IBAction)openTutorial:(id)sender
{
	[self showTemplate:@"Tutorial"];
}

- (IBAction)templateBeatSheet:(id)sender {
	[self showTemplate:@"Beat Sheet"];
}

- (void)showTemplate:(NSString*)name {
	name = [name stringByReplacingOccurrencesOfString:@".fountain" withString:@""];
	
	NSURL* url = [BeatTemplates.shared getTemplateURLWithFilename:name];
	
	if (url) [[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:url copying:YES displayName:name error:nil];
	else NSLog(@"ERROR: Can't find template");
}

#pragma mark - Fountain syntax references & help

-(void)windowWillClose:(NSNotification *)notification {
	// Dealloc window controllers on close
	
	NSWindow* window = notification.object;
	
	if (window == _episodePrinter.window) {
		[NSApp stopModal];
		_episodePrinter = nil;
	}
	else if (window == _preferencesPanel.window) {
		_preferencesPanel = nil;
	}
	else if (window == _pluginLibrary.window) {
		[_pluginLibrary clearWebView];
		_pluginLibrary = nil;
	}
}

#pragma mark - Launch screen

-(void)showLaunchScreen
{
	if (NSDocumentController.sharedDocumentController.documents.count > 0) return;
	[self showLaunchScreenWithViewControllerName:@"LaunchScreen"];
}

-(void)showTemplates
{
	[self showLaunchScreenWithViewControllerName:@"Templates"];
}

- (void)showLaunchScreenWithViewControllerName:(NSString*)viewControllerName
{
	if (_welcomeWindow == nil) {
		_welcomeWindow = [NSWindow.alloc initWithContentRect:NSMakeRect(0, 0, 0, 0) styleMask:NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:false];
		_welcomeWindow.title = @"";
		_welcomeWindow.titlebarAppearsTransparent = true;
		_welcomeWindow.movableByWindowBackground = true;
		_welcomeWindow.releasedWhenClosed = false;
		if (@available(macOS 10.14, *)) {
			_welcomeWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
		}
	}

	NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Launch Screen" bundle:NSBundle.mainBundle];
	NSViewController* vc = [storyboard instantiateControllerWithIdentifier:viewControllerName];

	NSRect frame = vc.view.frame;
	NSSize screen = _welcomeWindow.screen.frame.size;
	frame.origin.x = (screen.width - frame.size.width) / 2;
	frame.origin.y = (screen.height - frame.size.height) / 2;
	
	[_welcomeWindow setFrame:frame display:true];
	
	_welcomeWindow.contentViewController = vc;
	[_welcomeWindow makeCentered];
	[_welcomeWindow makeKeyAndOrderFront:nil];
}

- (void)closeLaunchScreen
{
	[self.welcomeWindow close];
	_welcomeWindow = nil;
}

- (IBAction)showAboutScreen:(id) sender {
	if (!_about) _about = BeatAboutScreen.new;
	[_about show];
}

- (IBAction)openPreferences:(id)sender {
	if (!_preferencesPanel) {
		_preferencesPanel = BeatPreferencesPanel.new;
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_preferencesPanel.window];
	}
	[_preferencesPanel show];
}

- (IBAction)openConsole:(id)sender {
	[BeatConsole.shared openConsole];
}


#pragma mark - Handoff
/*
- (BOOL)application:(NSApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<NSUserActivityRestoring>> * _Nonnull))restorationHandler
{
	return false;
}
*/

#pragma mark - File Import

- (IBAction)importFDX:(id)sender
{
	[BeatFileImport.new fdx];
}
- (IBAction)importCeltx:(id)sender
{
	[BeatFileImport.new celtx];
}
- (IBAction)importHighland:(id)sender
{
	[BeatFileImport.new highland];
}
- (IBAction)importFadeIn:(id)sender
{
	[BeatFileImport.new fadeIn];
}
- (IBAction)importTrelby:(id)sender
{
	[BeatFileImport.new trelby];
}
- (IBAction)importPDF:(id)sender
{
	[BeatFileImport.new pdf];
}


#pragma mark - Generic methods for opening a plain-text file

- (id)newDocumentWithContents:(NSString*)string
{
	NSURL *tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
	NSError *error;
	
	[string writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	id document = [NSDocumentController.sharedDocumentController duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
	
	return document;
}

- (NSURL *)URLForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSUUID* uuid = NSUUID.new;
	NSURL* result = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@", prefix, uuid.UUIDString, prefix]]];

    return result;
}

- (IBAction)newDocument:(id)sender {
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

-(void)menuWillOpen:(NSMenu *)menu {
	if (menu == _backupMenu) {
		[self backupMenuItems];
	}
}

#pragma mark - Version control

// Shows a list of backup items

- (void)backupMenuItems
{
	[_backupMenu removeAllItems];
	
	NSDocument *doc = NSDocumentController.sharedDocumentController.currentDocument;
	NSURL *url = doc.fileURL;
	
	if (url) {
		NSArray *versions = [BeatBackup backupsWithName:url.lastPathComponent.stringByDeletingPathExtension];
		
		NSDateFormatter* df = NSDateFormatter.new;
		[df setDateStyle:NSDateFormatterShortStyle];
		[df setTimeStyle:NSDateFormatterShortStyle];
		
		// Revert to saved
		BeatMenuItemWithURL *toSaved = [BeatMenuItemWithURL.alloc initWithTitle:NSLocalizedString(@"backup.revertToSaved", nil) action:@selector(revertTo:) keyEquivalent:@""];
		toSaved.url = doc.fileURL;
		toSaved.tag = NSNotFound;
		[_backupMenu addItem:toSaved];
		
		// Browse versions
		if (@available(macOS 13.0, *)) {
			// NSMenuItem *browse = [NSMenuItem.alloc initWithTitle:NSLocalizedString(@"backup.browseVersions", nil) action:@selector(browseVersions:) keyEquivalent:@""];
			// [_backupMenu addItem:browse];
		}
		
		[_backupMenu addItem:NSMenuItem.separatorItem];
		
		for (BeatBackupFile *version in versions) {
			NSString *modificationTime = [df stringFromDate:version.date];
			BeatMenuItemWithURL *item = [BeatMenuItemWithURL.alloc initWithTitle:modificationTime action:@selector(restoreBackup:) keyEquivalent:@""];
			item.url = [NSURL fileURLWithPath:version.path];
			[_backupMenu addItem:item];
		}
		
		if (versions.count) {
			[_backupMenu addItem:NSMenuItem.separatorItem];
		}
	}
	
	NSMenuItem *backupVault = [NSMenuItem.alloc initWithTitle:[BeatLocalization localizedStringForKey:@"backup.backupVault"] action:@selector(openBackupFolder:) keyEquivalent:@""];
	[_backupMenu addItem:backupVault];
}

- (IBAction)restoreBackup:(id)sender
{
	BeatModalInput *input = BeatModalInput.alloc.init;
	[input confirmBoxWithMessage:[BeatLocalization localizedStringForKey:@"backup.reverting.title"]
							text:[BeatLocalization localizedStringForKey:@"backup.reverting.message"] forWindow:NSDocumentController.sharedDocumentController.currentDocument.windowForSheet completion:^(bool result) {
		if (!result) return;
		
		BeatMenuItemWithURL *item = sender;
		if (item.url == nil) {
			NSLog(@"ERROR, no URL found");
			return;
		}
		
		NSError *error;
		if (item.url == NSDocumentController.sharedDocumentController.currentDocument.fileURL) {
			// Revert to saved
			[NSDocumentController.sharedDocumentController.currentDocument revertDocumentToSaved:nil];
		} else {
			[NSDocumentController.sharedDocumentController.currentDocument revertToContentsOfURL:item.url ofType:NSPlainTextDocumentType error:&error];
			if (error) NSLog(@"Error: %@", error);
		}
	}];
}

- (IBAction)openBackupFolder:(id)sender
{
	[BeatBackup openBackupFolder];
}

- (void)versionMenuItems {
	[_revertMenu removeAllItems];
	
	NSDocument *doc = NSDocumentController.sharedDocumentController.currentDocument;
	NSURL *url = doc.fileURL;
	if (!url) return;
	
	// Get available versions
	NSArray *versions = [NSFileVersion otherVersionsOfItemAtURL:url];
	
	NSDateFormatter* df = NSDateFormatter.new;
	[df setDateStyle:NSDateFormatterShortStyle];
	[df setTimeStyle:NSDateFormatterShortStyle];
	
	// Add revert to saved
	NSMenuItem *toSaved = [[NSMenuItem alloc] initWithTitle:@"Saved" action:@selector(revertTo:) keyEquivalent:@""];
	toSaved.state = (!doc.isDocumentEdited) ? NSOnState : NSOffState;
	toSaved.tag = NSNotFound;
	
	[_revertMenu addItem:toSaved];
	[_revertMenu addItem:NSMenuItem.separatorItem];
	
	// Only allow 10
	NSInteger count = 0;
	
	for (NSInteger i = versions.count - 1; i >= 0; i--) {
		// Don't allow more than 10 versions
		if (count > 10) break;
		
		NSFileVersion *version = versions[i];
		NSString *modificationTime = [df stringFromDate:version.modificationDate];
		
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:modificationTime action:@selector(revertTo:) keyEquivalent:@""];
		item.tag = i;
		
		if ([[(Document*)doc revertedTo] isEqualTo:version.URL]) item.state = NSOnState;
		
		[_revertMenu addItem:item];
		
		count++;
	}
	
	[_revertMenu addItem:NSMenuItem.separatorItem];
	[_revertMenu addItemWithTitle:@"Browse Versions..." action:@selector(browseVersions:) keyEquivalent:@""];
}

- (void)browseVersions:(id)sender {
	[NSDocumentController.sharedDocumentController.currentDocument browseDocumentVersions:self];
}

- (void)revertTo:(id)sender {
	BeatModalInput *input = BeatModalInput.alloc.init;
	[input confirmBoxWithMessage:@"Revert File" text:@"Any unsaved changes will be lost when reverting to an earlier version." forWindow:NSDocumentController.sharedDocumentController.currentDocument.windowForSheet completion:^(bool result) {
		if (!result) return;
		
		NSMenuItem *item = sender;
	
		NSError *error;
		
		if (item.tag == NSNotFound) {
			// Revert to saved
			[NSDocumentController.sharedDocumentController.currentDocument revertDocumentToSaved:nil];
			return;
		}
		
		NSArray *versions = [NSFileVersion otherVersionsOfItemAtURL:NSDocumentController.sharedDocumentController.currentDocument.fileURL];
		NSFileVersion *version = versions[item.tag];
		
		[NSDocumentController.sharedDocumentController.currentDocument revertToContentsOfURL:version.URL ofType:NSPlainTextDocumentType error:&error];
		if (error) NSLog(@"Error: %@", error);
		
	} buttons:@[@"Revert", @"Cancel"]];
}

 
#pragma mark - Plugin support

- (IBAction)openPluginLibrary:(id)sender {
	_pluginLibrary = BeatPluginLibrary.alloc.init;
	_pluginLibrary.window.delegate = self;
	[_pluginLibrary show];
}

- (IBAction)runStandalonePlugin:(id)sender {
	// This runs a plugin which is NOT tied to the document
	NSMenuItem *item = sender;
	NSString *pluginName = item.title;
	
	BeatPlugin *parser = BeatPlugin.new;
	BeatPluginData *plugin = [BeatPluginManager.sharedManager pluginWithName:pluginName];
	[parser loadPlugin:plugin];
	parser = nil;
}

#pragma mark - Episode Printing
// Sorry, I don't know how to work with window controllers, so this is here :-(

- (IBAction)printEpisodes:(id)sender {
	if (!_episodePrinter) {
		_episodePrinter = BeatEpisodePrinter.new;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_episodePrinter.window];
	}
	
	[NSApp runModalForWindow:_episodePrinter.window];
}


#pragma mark - Show notifications

- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval {
	if (!_notifications) _notifications = BeatNotifications.new;
	[_notifications showNotification:title body:body identifier:identifier oneTime:showOnce interval:interval];
}

#pragma mark - Supporting methods

- (NSURL*)appDataPath:(NSString*)subPath {
	return [BeatAppDelegate appDataPath:subPath];
}
+ (NSURL*)appDataPath:(NSString*)subPath {
	return [BeatPaths appDataPath:subPath];
}

- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
	return [BeatAppDelegate pathForTemporaryFileWithPrefix:prefix];
}
+ (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSUUID* uuid = NSUUID.new;
	NSString* result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuid.UUIDString]];

	return result;
}

@end
