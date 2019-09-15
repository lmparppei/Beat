//
//  ApplicationDelegate.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license

#import "ApplicationDelegate.h"

@implementation ApplicationDelegate
//@synthesize window;
//@synthesize versionField;

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
	
	return self;
}

-(void) awakeFromNib {
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
	
	NSString *versionString = [NSString stringWithFormat:@"beat %@", version];
	[versionField setStringValue:versionString];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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

@end
