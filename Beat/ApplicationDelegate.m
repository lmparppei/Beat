//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license

#import "ApplicationDelegate.h"
#import "FDXImport.h"

@implementation ApplicationDelegate
@synthesize recentFiles;

#pragma mark - Help

- (instancetype) init {	
	// This might be a silly implementation, but ..... well.
	// Let's close the welcome screen if any sort of document has been opened
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document open" object:nil queue:nil usingBlock:^(NSNotification *note) {
		if (self->_startModal && [self->_startModal isVisible]) {
			[self closeStartModal];
		}
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Document close" object:nil queue:nil usingBlock:^(NSNotification *note) {
		NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
		
		if ([openDocuments count] == 1 && self->_startModal && ![self->_startModal isVisible]) {
			//[self showStartModal];
			[self->_startModal setIsVisible:true];
			[self->recentFiles deselectAll:nil];
			[self->recentFiles reloadData];
		}
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:@"Show about screen" object:nil queue:nil usingBlock:^(NSNotification *note) {
		//if (self->_startModal && [self->_startModal isVisible]) {
		//	[self closeStartModal];
		//}
	}];
	
	return self;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

-(void) awakeFromNib {
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
	
	NSString *versionString = [NSString stringWithFormat:@"beat %@", version];
	[versionField setStringValue:versionString];
	[aboutVersionField setStringValue:versionString];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//[NSApplication.sharedApplication setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
	[NSApplication sharedApplication].automaticCustomizeTouchBarMenuItemEnabled = YES; 
	
	// Only open splash screen if no documents were opened by default
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	if ([openDocuments count] == 0 && self->_startModal && ![self->_startModal isVisible]) {
		[self->_startModal setIsVisible:true];
	}
	
	_darkMode = false;
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSAppearance currentAppearance] ?: [NSApp effectiveAppearance];
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			_darkMode = true;
		}
	}
}
- (bool)isDark {
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = [NSAppearance currentAppearance] ?: [NSApp effectiveAppearance];
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			return true;
		}
	}
	
	return _darkMode;
}

- (IBAction)showFountainSyntax:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io/syntax#section-overview"];
}

- (IBAction)showFountainWebsite:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io"];
}

- (IBAction)showBeatWebsite:(id)sender
{
    [self openURLInWebBrowser:@"https://kapitan.fi/beat/"];
}

- (void)openURLInWebBrowser:(NSString*)urlString
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

// Close welcome screen
- (IBAction)closeStartModal
{
	[_startModal close];
}
- (void) toggleDarkMode {
	_darkMode = !_darkMode;
}

- (IBAction)showAboutScreen:(id) sender {
	[self->_aboutModal setIsVisible:true];
	
	NSString * rtfFile = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"];
	[aboutText readRTFDFromFile:rtfFile];
}

- (IBAction)importFDX:(id)sender
{
	/*
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Continue"];
	[alert setMessageText:@"Final Draft Import"];
	//[alert setInformativeText:@“NSWarningAlertStyle \r Do you want to continue with delete of selected records"];
	[alert setInformativeText:@"NOTE: This feature is still under development. Basic elements (such as dialogue, actions, transitions) will import correctly, but you should double-check the results. Sorry for any inconvience!"];
	[alert setAlertStyle:NSAlertStyleWarning];
	
	[alert beginSheetModalForWindow:NSApp.windows[0] completionHandler:^(NSInteger result) {
*/
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
								
				//[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:referenceFile copying:YES displayName:@"Tutorial" error:nil];
/*
				[[fdxImport scriptAsString] writeToURL:tempURL atomically:YES encoding:NSUTF8StringEncoding error:&error];

				[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
				NSLog(@"jaa? %@", tempURL);
*/
				
			}
		}];
	//}];
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

@end
