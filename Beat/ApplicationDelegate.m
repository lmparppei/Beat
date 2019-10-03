//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license

#import "ApplicationDelegate.h"

@implementation ApplicationDelegate
@synthesize recentFiles;

#pragma mark - Help

- (instancetype) init {
	// Omg let's test this out
	_darkMode = true;
	
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
/*
    void (^completionHander)(NSDocument * _Nullable, BOOL, NSError * _Nullable) = ^void(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        //[document setFileURL:[[NSURL alloc] init]];
		[document setFileURL:nil];
    };
	//[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:referenceFile display:YES completionHandler:completionHander];
*/
	
	// Let's copy the tutorial file
	[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:referenceFile copying:false displayName:@"Tutorial" error:nil];
	
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	if (flag) return NO; else return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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

@end
