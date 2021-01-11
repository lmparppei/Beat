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

#import "BeatTest.h"

#define APPNAME @"Beat"

@interface ApplicationDelegate ()
@property (nonatomic) RecentFiles *recentFilesSource;

@property (weak) IBOutlet NSWindow* startModal;
@property (weak) IBOutlet NSOutlineView* recentFiles;

@property (weak) IBOutlet NSWindow* acknowledgementsModal;
@property (weak) IBOutlet NSTextView* acknowledgementsTextView;

@property (weak) IBOutlet NSMenuItem *menuManual;
@property (weak) IBOutlet NSWindow *manualWindow;

@property (weak) IBOutlet NSTextField* versionField;

@property (nonatomic) BeatBrowserView *browser;
@property (nonatomic) BeatAboutScreen *about;
@property (nonatomic) BeatEpisodePrinter *episodePrinter;
@end

@implementation ApplicationDelegate

#define DEVELOPMENT NO
#define DARKMODE_KEY @"Dark Mode"
#define LATEST_VERSION_KEY @"Latest Version"

#pragma mark - Help

- (instancetype) init {
	return [super init];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	[self checkAutosavedFiles];
	
	// Run tests
	//[[BeatTest alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_recentFilesSource = [[RecentFiles alloc] init];
	self.recentFiles.dataSource = _recentFilesSource;
	self.recentFiles.delegate = _recentFilesSource;
	[self.recentFiles setDoubleAction:@selector(doubleClickDocument)];
	[self.recentFiles reloadData];

	// Let's close the welcome screen if any sort of document has been opened
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document open" object:nil queue:nil usingBlock:^(NSNotification *note) {
		if (self.startModal && [self.startModal isVisible]) {
			[self closeStartModal];
		}
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document close" object:nil queue:nil usingBlock:^(NSNotification *note) {
		NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
		
		if ([openDocuments count] == 1 && self.startModal && ![self.startModal isVisible]) {
			//[self showStartModal];
			
			[self.startModal setIsVisible:true];
			[self.recentFiles deselectAll:nil];
			[self.recentFiles reloadData];
		}
	}];
		
	// Check for pro version content
	NSString* proContentPath = [[NSBundle mainBundle] pathForResource:@"beat_manual" ofType:@"html"];
	if (proContentPath) _proMode = YES;
	
	[NSApplication sharedApplication].automaticCustomizeTouchBarMenuItemEnabled = YES;
	
	// Only open splash screen if no documents were opened by default
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	if ([openDocuments count] == 0 && self.startModal && ![self.startModal isVisible]) {
		[self.startModal setIsVisible:true];
	}
	
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
	
	[self setupPlugins];
	
	[self checkVersion];
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

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

- (void) awakeFromNib {
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

#pragma mark - Autosave

- (void)checkAutosavedFiles {
	// We will run this operation in another thread, so that the app can start and opening recovered documents won't mess up any other logic built into the app.
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
		__block NSFileManager *fileManager = [NSFileManager defaultManager];
		
		NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
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
						} else {
							// If the user really doesn't want to spare this file, let's fucking delete it FOREVER!!!
							[fileManager removeItemAtPath:[appSupportDir stringByAppendingPathComponent:filename] error:nil];
						}
					}];
				} else {
					// Remove the autosave
					[fileManager removeItemAtPath:[appSupportDir stringByAppendingPathComponent:filename] error:nil];
				}
				
			});
		}
	});
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	if (flag) return NO; else return YES;
}


#pragma mark - Dark mode stuff

// This is some spaghetti but seems to work for now
// We have to check if OS is set to dark AND if the user has forced either mode

- (bool)isForcedDarkMode {
	if (![self OSisDark]) return _forceDarkMode;
	return NO;
}
- (bool)isForcedLightMode {
	if ([self OSisDark]) return _forceLightMode;
	return NO;
}
- (bool)isDark {
	// Uh... if OS set to dark mode, Beat is forced to use it too
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSApp effectiveAppearance];
		if (appearance == nil) appearance = [NSAppearance currentAppearance];
		
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			if (!_forceLightMode) return YES; else return NO;
		} else {
			if (!_forceDarkMode) return NO; else return YES;
		}
	}
	if (_forceDarkMode) return YES;
	
	return _darkMode;
}
- (bool)OSisDark {
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSApp effectiveAppearance];
		if (!appearance) appearance = [NSAppearance currentAppearance];
		
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			return true;
		}
	}
	return NO;
}
- (void) toggleDarkMode {
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
	else NSLog(@"can't find template");
}

#pragma mark - Fountain syntax references & help

-(void)windowWillClose:(NSNotification *)notification {
	// Dealloc window controllers on close
	
	NSWindow* window = notification.object;
	
	if (window == _browser.window) {
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
-(void)doubleClickDocument {
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
	NSMenuItem *menuItem = _pluginMenu.itemArray.firstObject;
	[_pluginMenu removeAllItems];
	
	BeatPluginManager *plugins = [[BeatPluginManager alloc] init];
	
	for (NSString *pluginName in plugins.pluginNames) {
		NSMenuItem *item = [menuItem copy];
		item.title = pluginName;
		[_pluginMenu addItem:item];
	}
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

@end
