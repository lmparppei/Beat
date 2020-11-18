//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license

#import "ApplicationDelegate.h"
#import "FDXImport.h"
#import "CeltxImport.h"
#import "HighlandImport.h"
#import "RecentFiles.h"

#import "BeatTest.h"
#import "BeatFileImport.h"

@interface ApplicationDelegate ()
@property (nonatomic) RecentFiles *recentFilesSource;
@end

@implementation ApplicationDelegate

#define DEVELOPMENT YES
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
	//BeatTest *test = [[BeatTest alloc] init];
	
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
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Show about screen" object:nil queue:nil usingBlock:^(NSNotification *note) {
		//if (self.startModal && [self.startModal isVisible]) {
		//	[self closeStartModal];
		//}
	}];
	
	// Check for pro version content
	NSString* proContentPath = [[NSBundle mainBundle] pathForResource:@"beat_manual" ofType:@"html"];
	if (proContentPath) _proMode = YES;
	
	//[NSApplication.sharedApplication setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
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
	
	[self checkVersion];
}
-(void)doubleClickDocument {
	[_recentFilesSource doubleClickDocument:nil];
}
-(void)checkVersion {
	NSInteger latestVersion = [[[NSUserDefaults standardUserDefaults] objectForKey:LATEST_VERSION_KEY] integerValue];
	NSInteger currentVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue];
	
	if (latestVersion == 0 || currentVersion > latestVersion) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%lu", currentVersion] forKey:LATEST_VERSION_KEY];
		if (!DEVELOPMENT) [self showPatchNotes:nil];
	} else {
		// Up to date
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

- (void) awakeFromNib {
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
	
	NSString *versionString = [NSString stringWithFormat:@"beat %@", version];
	[_versionField setStringValue:versionString];
	[_aboutVersionField setStringValue:versionString];
	
	if (_proMode) {
		[self.menuManual setHidden:NO];
	}
	
	[self.startModal becomeKeyWindow];
	[self.startModal setAcceptsMouseMovedEvents:YES];
	[self.startModal setMovable:YES];
	[self.startModal setMovableByWindowBackground:YES];
}

- (void)checkAutosavedFiles {
	// We will run this operation in another thread, so that the app can start and opening recovered documents won't mess up any other logic built into the app. Thanks for calling it logic, though.
	
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
					//NSURL *recoverURL = [NSURL fileURLWithPath:appSupportDir];
					//recoverURL = [recoverURL URLByAppendingPathComponent:file];
					
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
					// Again, if REST IN PEACE, motherfucker!!!
					[fileManager removeItemAtPath:[appSupportDir stringByAppendingPathComponent:filename] error:nil];
				}
				
			});
		}
	});
}

- (IBAction)showReference:(id)sender
{
    NSURL* referenceFile = [[NSBundle mainBundle] URLForResource:@"Tutorial"
                                                   withExtension:@"fountain"];

	// Let's copy the tutorial file
	[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:referenceFile copying:YES displayName:@"Tutorial" error:nil];
}

- (IBAction)templateBeatSheet:(id)sender {
	NSURL* referenceFile = [[NSBundle mainBundle] URLForResource:@"Beat Sheet"
												   withExtension:@"fountain"];
	// Let's copy the beat sheet file
	[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:referenceFile copying:YES displayName:@"Beat Sheet" error:nil];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	if (flag) return NO; else return YES;
}


#pragma mark - Dark mode stuff

// This is a spaghetti but seems to work for now

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

#pragma mark - Fountain syntax references & help

- (IBAction)showPatchNotes:(id)sender {
	self.manualWindow.title = @"Patch Notes";
	
	CGFloat width = 550;
	CGFloat height = 700;
	[self.manualWindow setFrame:NSMakeRect(
										  (NSScreen.mainScreen.frame.size.width - width) / 2,
										  (NSScreen.mainScreen.frame.size.height - height) / 2,
										  width, height
										  )
						 display:YES];
	
	NSString * htmlPath = [[NSBundle mainBundle] pathForResource:@"Patch Notes" ofType:@"html"];
	[self.manualView loadFileURL:[NSURL fileURLWithPath:htmlPath] allowingReadAccessToURL:[NSURL fileURLWithPath:[htmlPath stringByDeletingLastPathComponent] isDirectory:YES]];
	[self.manualWindow setIsVisible:true];
}

- (IBAction)showManual:(id)sender {
	//[[NSBundle mainBundle] loadNibNamed:@"BeatManual" owner:self topLevelObjects:nil];
	[self.manualWindow setIsVisible:true];
	self.manualWindow.title = @"Beat Manual";
	
	NSString * htmlPath = [[NSBundle mainBundle] pathForResource:@"beat_manual" ofType:@"html"];
	NSLog(@"path %@", htmlPath);
	[self.manualView loadFileURL:[NSURL fileURLWithPath:htmlPath] allowingReadAccessToURL:[NSURL fileURLWithPath:[htmlPath stringByDeletingLastPathComponent] isDirectory:YES]];
	//[aboutText readRTFDFromFile:rtfFile];
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

// Close welcome screen
- (IBAction)closeStartModal
{
	[_startModal close];
}

- (IBAction)showAboutScreen:(id) sender {
	[self.aboutModal setIsVisible:true];
	
	NSString * rtfFile = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"];
	[_aboutText readRTFDFromFile:rtfFile];
}

- (IBAction)showAcknowledgements:(id) sender {
	[self.acknowledgementsModal setIsVisible:YES];
}

#pragma mark - File Import
/*
 
 I should make a generic import class with delegation to make this cleaner.
 
 BeatImport *import = [[BeatImport alloc] initWithDelegate:self];
 [import fdx];
 [import celtx];
 [import highland];
  
 */

- (IBAction)importFDX:(id)sender
{
	BeatFileImport *import = [[BeatFileImport alloc] init];
	[import fdx];
	
	/*
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setAllowedFileTypes:@[@"fdx"]];

	[openDialog beginWithCompletionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			
			__block FDXImport *fdxImport;
			fdxImport = [[FDXImport alloc] initWithURL:openDialog.URL completion:^(void) {
				if ([fdxImport.script count] > 0) {
					NSURL *tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
					NSError *error;
					
					[[fdxImport scriptAsString] writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
					
					if (!error) {
						dispatch_async(dispatch_get_main_queue(), ^(void){
							[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
						});
					}
				}
			}];
		}
	}];
	 */
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

- (void)openFileWithContents:(NSString*)string {
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

/*
 // Some experiments in hacking the MM Scheduling .sex file format
- (IBAction)hackSex:(id)sender {
	NSString * sexFile = [[NSBundle mainBundle] pathForResource:@"mms.sex" ofType:@""];

	NSData * contents = [NSData dataWithContentsOfFile:sexFile];
	//NSString *string = [[NSString alloc] initWithData:contents encoding:NSISOLatin1StringEncoding];
	
	const char* fileBytes = (const char*)[contents bytes];
	NSUInteger length = [contents length];
	NSUInteger index;

	NSMutableString *string = [NSMutableString string];
	
	bool heading = NO;
	bool text = NO;
	
	for (index = 0; index<length; index++)
	{
		char aByte = fileBytes[index];
		
		if (fileBytes[index] == 0){
			[string appendString:[NSString stringWithFormat:@" "]];
		}
		else if (fileBytes[index] == 1) {
			// Start of heading
			[string appendString:[NSString stringWithFormat:@"["]];
			heading = YES;
		}
		else if (fileBytes[index] == 2) {
			// Start of text
			[string appendString:[NSString stringWithFormat:@"{"]];
			text = YES;
		}
		else if (fileBytes[index] == 3) {
			// End of text
			[string appendString:[NSString stringWithFormat:@"}"]];
			text = NO;
		}
		else if (fileBytes[index] == 4) {
			[string appendString:[NSString stringWithFormat:@"]"]];
			heading = NO;
			text = NO;
		}
		else if (fileBytes[index] == 10) {
			// Newline
			[string appendString:[NSString stringWithFormat:@""]];
		}
		else if (fileBytes[index] == 12) {
			// New page
			NSLog(@"new page");
			[string appendString:[NSString stringWithFormat:@""]];
			heading = NO;
			text = NO;
		}
		else if (fileBytes[index] == 20) {
			NSLog(@"device control");
			[string appendString:[NSString stringWithFormat:@"/"]];
		}
		else if (fileBytes[index] == 16) {
			NSLog(@"data link escape");
			[string appendString:[NSString stringWithFormat:@"\\"]];
		}

		else if (fileBytes[index] == 8) {
			// Backspace
			[string appendString:[NSString stringWithFormat:@""]];
		}
		else if (fileBytes[index] == 9) {
			[string appendString:[NSString stringWithFormat:@"\t"]];
		}
		else if (fileBytes[index] == 32) {
			// Normal space
			[string appendString:[NSString stringWithFormat:@" "]];
		}
		else if (fileBytes[index] == -123) {
			// Scandic Ö
			[string appendString:[NSString stringWithFormat:@"Ö"]];
		}
		else if (fileBytes[index] == -128) {
			// Scandic Ä
			[string appendString:[NSString stringWithFormat:@"Ä"]];
		}

		else if (fileBytes[index] == '#') {
			[string appendString:[NSString stringWithFormat:@"#"]];
		}
		else {
			[string appendString:[NSString stringWithFormat:@"%c", aByte]];
		}
		
		NSLog(@"char %c / %i", aByte, fileBytes[index]);
		
	}
	
	
	NSLog(@"content %@", string);
}
 */


@end
