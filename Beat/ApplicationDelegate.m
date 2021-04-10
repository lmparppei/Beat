//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license

#import "ApplicationDelegate.h"
#import "RecentFiles.h"
#import "BeatFileImport.h"
#import "BeatPluginManager.h"
#import "BeatBrowserView.h"
#import "BeatAboutScreen.h"
#import "BeatEpisodePrinter.h"

#ifdef ADHOC
#import <Sparkle/Sparkle.h>
#endif

#import "BeatTest.h"

#define APPNAME @"Beat"

@interface ApplicationDelegate ()
@property (nonatomic) RecentFiles *recentFilesSource;

@property (weak) IBOutlet NSWindow* startModal;
@property (weak) IBOutlet NSOutlineView* recentFiles;

@property (weak) IBOutlet NSMenuItem *checkForUpdatesItem;
@property (weak) IBOutlet NSMenuItem *menuManual;

@property (weak) IBOutlet NSTextField* versionField;

@property (nonatomic) BeatBrowserView *browser;
@property (nonatomic) BeatAboutScreen *about;
@property (nonatomic) BeatEpisodePrinter *episodePrinter;


#ifdef ADHOC
// I'm supporting ad hoc distribution for now
@property (nonatomic) IBOutlet SUUpdater *updater;
#endif

@end

@implementation ApplicationDelegate

#define DEVELOPMENT NO
#define DARKMODE_KEY @"Dark Mode"
#define LATEST_VERSION_KEY @"Latest Version"

#pragma mark - Help

- (instancetype) init {
	self = [super init];
	return self;
}

- (void) awakeFromNib {

#ifdef ADHOC
	// Add CHECK FOR UPDATES menu item
	NSLog(@"# ADHOC");
	self.updater = [[SUUpdater alloc] init];
	_checkForUpdatesItem.action = @selector(checkForUpdates:);
#else
	NSLog(@"# APPSTORE");
	[_checkForUpdatesItem.menu removeItem:_checkForUpdatesItem];
#endif
	
	NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
	
	NSString *versionString = [NSString stringWithFormat:@"beat %@", version];
	[_versionField setStringValue:versionString];
	
	if (_proMode) {
		[self.menuManual setHidden:NO];
	}
	
	[self.startModal becomeKeyWindow];
	[self.startModal setAcceptsMouseMovedEvents:YES];
	[self.startModal setMovable:YES];
	[self.startModal setMovableByWindowBackground:YES];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	[self checkAutosavedFiles];
	
#ifdef ADHOC
	// Run Sparkle if this is an ad hoc distribution
	if (self.updater.automaticallyChecksForUpdates) [self.updater checkForUpdatesInBackground];
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_recentFilesSource = [[RecentFiles alloc] init];
	self.recentFiles.dataSource = _recentFilesSource;
	self.recentFiles.delegate = _recentFilesSource;
	[self.recentFiles setDoubleAction:@selector(doubleClickDocument)];
	[self.recentFiles reloadData];
	
	[self setupDocumentOpenListener];
	[self checkProContent];
	[self checkDarkMode];

	// Only open splash screen if no documents were opened by default
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	if ([openDocuments count] == 0 && self.startModal && ![self.startModal isVisible]) {
		[self.startModal setIsVisible:true];
	}
	
	// Lastly, open patch notes if the app was recently updated
	[self checkVersion];
}

-(void)checkForUpdates:(id)sender {
#ifdef ADHOC
	[self.updater checkForUpdates:sender];
#endif
}

-(void)checkDarkMode {
	_darkMode = [[NSUserDefaults standardUserDefaults] boolForKey:DARKMODE_KEY];
	
	// If the OS is set to dark mode, we'll force it
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSAppearance currentAppearance] ?: [NSApp effectiveAppearance];
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			_darkMode = true;
		} else {
			if (_darkMode) _forceDarkMode = YES;
		}
	}
}

-(void)checkProContent {
	// Check for pro version content
	NSString* proContentPath = [[NSBundle mainBundle] pathForResource:@"beat_manual" ofType:@"html"];
	if (proContentPath) _proMode = YES;
}

-(void)checkVersion {
	NSInteger latestVersion = [[[NSUserDefaults standardUserDefaults] objectForKey:LATEST_VERSION_KEY] integerValue];
	NSInteger currentVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue];
	
	// Show patch notes if it's the first time running Beat
	if (latestVersion == 0 || currentVersion > latestVersion) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%lu", currentVersion] forKey:LATEST_VERSION_KEY];
		if (!DEVELOPMENT) [self showPatchNotes:nil];
	}
}

-(void)setupDocumentOpenListener {
	// Let's close the welcome screen if any sort of document has been opened
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document open" object:nil queue:nil usingBlock:^(NSNotification *note) {
		if (self.startModal && [self.startModal isVisible]) {
			[self closeStartModal];
		}
	}];
	
	// And show modal if all documents were closed
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document close" object:nil queue:nil usingBlock:^(NSNotification *note) {
		NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
		
		if ([openDocuments count] == 1 && self.startModal && ![self.startModal isVisible]) {
			[self.startModal setIsVisible:true];
			[self.recentFiles deselectAll:nil];
			[self.recentFiles reloadData];
		}
	}];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

#pragma mark - Autosave

- (void)checkAutosavedFiles {
	// We will run this operation in another thread, so that the app can start and opening recovered documents won't mess up any other logic built into the app.
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
		__block NSFileManager *fileManager = [NSFileManager defaultManager];
		
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
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = [NSString stringWithFormat:@"%@", filename];
				alert.informativeText = @"An unsaved script was found. Do you want to recover the latest autosaved version of this file?";
				[alert addButtonWithTitle:@"Recover"];
				[alert addButtonWithTitle:@"Cancel"];

				NSModalResponse response = [alert runModal];

				if (response == NSAlertFirstButtonReturn) {
					NSString *recoveredFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@" (Recovered)"] stringByAppendingString:@".fountain"];
					
					NSSavePanel *saveDialog = [NSSavePanel savePanel];
					[saveDialog setAllowedFileTypes:@[@"Fountain"]];
					[saveDialog setNameFieldStringValue:recoveredFilename];
					
					[saveDialog beginWithCompletionHandler:^(NSInteger result) {
						if (result == NSFileHandlingPanelOKButton) {

							NSError *error;
							@try {
								[fileManager moveItemAtPath:[appSupportDir stringByAppendingPathComponent:file] toPath:saveDialog.URL.path error:&error];
								
								[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:saveDialog.URL display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
								}];
								if (error) {
									NSAlert *alert = [[NSAlert alloc] init];
									alert.messageText = [NSString stringWithFormat:@"Error recovering %@", filename];
									alert.informativeText = @"The file could not be recovered, but don't worry, it is still safe. Restart Beat and try to recover into another location.";
									alert.alertStyle = NSAlertStyleWarning;
									[alert runModal];
								}
							} @catch (NSException *exception) {
							} @finally {
							}
						} else {
							// If the user really doesn't want to spare this file, let's fucking delete it FOREVER!!!
							[self deleteAutosaveFile:[appSupportDir stringByAppendingPathComponent:filename]];
						}
					}];
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

- (bool)isForcedDarkMode {
	if (![self OSisDark]) return _forceDarkMode;
	return NO;
}
- (bool)isForcedLightMode {
	if ([self OSisDark]) return _forceLightMode;
	return NO;
}

- (bool)isDark {
	if ([self OSisDark]) {
		// OS in dark mode
		if (_forceLightMode) return NO;
		else return YES;
	} else {
		// OS in light mode
		if (_forceDarkMode) return YES;
		else return NO;
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
	
	[[NSUserDefaults standardUserDefaults] setBool:_darkMode forKey:DARKMODE_KEY];
}

#pragma mark - Tutorial and templates

- (IBAction)showReference:(id)sender
{
	[self showTemplate:@"Tutorial"];
}

- (IBAction)templateBeatSheet:(id)sender {
	[self showTemplate:@"Beat Sheet"];
}

- (void)showTemplate:(NSString*)name {
	NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:@"fountain"];
	
	if (url) [[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:url copying:YES displayName:name error:nil];
	else NSLog(@"ERROR: Can't find template");
}

#pragma mark - Fountain syntax references & help

-(void)windowWillClose:(NSNotification *)notification {
	// Dealloc window controllers on close
	
	NSWindow* window = notification.object;
	
	if (window == _browser.window) {
		[_browser resetWebView]; // Avoid retain cycle
		_browser = nil;
	}
	else if (window == _episodePrinter.window) {
		[NSApp stopModal];
		_episodePrinter = nil;
	}
}

- (IBAction)showPatchNotes:(id)sender {
	if (!_browser) {
		_browser = [[BeatBrowserView alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_browser.window];
	}
	
	NSURL *url = [NSBundle.mainBundle URLForResource:@"Patch Notes" withExtension:@"html"];
	[_browser showBrowser:url withTitle:@"Patch Notes" width:550 height:640];
}

- (IBAction)showManual:(id)sender {
	if (!_browser) {
		_browser = [[BeatBrowserView alloc] init];
	}
	
	NSURL *url = [NSBundle.mainBundle URLForResource:@"beat_manual" withExtension:@"html"];
	[_browser showBrowser:url withTitle:@"(beat manual)" width:600 height:500];
}

- (IBAction)showFountainSyntax:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io/syntax#section-overview"];
}
- (IBAction)showSupport:(id)sender
{
    [self openURLInWebBrowser:@"http://www.kapitan.fi/beat/support.html"];
}


- (IBAction)showFountainWebsite:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io"];
}

- (IBAction)showBeatWebsite:(id)sender
{
    [self openURLInWebBrowser:@"https://kapitan.fi/beat/"];
}
- (IBAction)showBeatSource:(id)sender
{
    [self openURLInWebBrowser:@"https://github.com/lmparppei/beat/"];
}

- (void)openURLInWebBrowser:(NSString*)urlString
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

#pragma mark - Misc UI

// Why is this here? Anyway, a method for the NSOutlineView showing recent files
- (void)doubleClickDocument {
	[_recentFilesSource doubleClickDocument:nil];
}

// Close welcome screen
- (IBAction)closeStartModal
{
	[_startModal close];
}

- (IBAction)showAboutScreen:(id) sender {
	if (!_about) {
		_about = [[BeatAboutScreen alloc] init];
	}
	[_about show];
}

#pragma mark - File Import

- (IBAction)importFDX:(id)sender
{
	BeatFileImport *import = [[BeatFileImport alloc] init];
	[import fdx];
}
- (IBAction)importCeltx:(id)sender
{
	BeatFileImport *import = [[BeatFileImport alloc] init];
	[import celtx];
}
- (IBAction)importHighland:(id)sender
{
	BeatFileImport *import = [[BeatFileImport alloc] init];
	[import highland];
}
- (IBAction)importFadeIn:(id)sender
{
	BeatFileImport *import = [[BeatFileImport alloc] init];
	[import fadeIn];
}

#pragma mark - Generic methods for opening a plain-text file

- (void)newDocumentWithContents:(NSString*)string {
	NSURL *tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
	NSError *error;
	
	[string writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
}

- (NSURL *)URLForTemporaryFileWithPrefix:(NSString *)prefix
{
    NSURL  *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;

    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);

    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
	result = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@", prefix, uuidStr, prefix]]];
    
    assert(result != nil);

    CFRelease(uuidStr);
    CFRelease(uuid);

    return result;
}

- (IBAction)newDocument:(id)sender {
	[[NSDocumentController sharedDocumentController] newDocument:nil];
	
}

#pragma mark - Plugin support

- (void)setupPlugins {	
	BeatPluginManager *plugins = [BeatPluginManager sharedManager];
	[plugins pluginMenuItemsFor:_pluginMenu];
}
-(void)menuWillOpen:(NSMenu *)menu {
	if (menu == _pluginMenu) [self setupPlugins];
}
- (void)openPluginFolder {
	BeatPluginManager *plugins = [BeatPluginManager sharedManager];
	[plugins openPluginFolder];
}


#pragma mark - Episode Printing
// Sorry, I don't know how to work with window controllers, so this is here :-(

- (IBAction)printEpisodes:(id)sender {
	if (!_episodePrinter) {
		_episodePrinter = [[BeatEpisodePrinter alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_episodePrinter.window];
	}
	//[_episodePrinter showWindow:_episodePrinter.window];
	[NSApp runModalForWindow:_episodePrinter.window];
}

#pragma mark - Supporting methods

- (NSURL*)appDataPath:(NSString*)subPath {
	//NSString* pathComponent = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	NSString* pathComponent = APPNAME;
	
	if ([subPath length] > 0) pathComponent = [pathComponent stringByAppendingPathComponent:subPath];
	
	NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
																		  NSUserDomainMask,
																		  YES);
	NSString* appSupportDir = [searchPaths firstObject];
	appSupportDir = [appSupportDir stringByAppendingPathComponent:pathComponent];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (![fileManager fileExistsAtPath:appSupportDir]) {
		[fileManager createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	return [NSURL fileURLWithPath:appSupportDir isDirectory:YES];
}

- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSString *  result;
	CFUUIDRef   uuid;
	CFStringRef uuidStr;

	uuid = CFUUIDCreate(NULL);
	assert(uuid != NULL);

	uuidStr = CFUUIDCreateString(NULL, uuid);
	assert(uuidStr != NULL);

	result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
	assert(result != nil);

	CFRelease(uuidStr);
	CFRelease(uuid);

	return result;
}

#pragma mark - Clear user defaults

- (void)removeUserDefaults
{
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary * dict = [userDefaults dictionaryRepresentation];
	for (id key in dict)
	{
		[userDefaults removeObjectForKey:key];
	}
	[userDefaults synchronize];
}

@end
