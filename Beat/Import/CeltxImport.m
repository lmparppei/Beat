//
//  CeltxImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

// A class for importing legacy desktop Celtx files

#import <Cocoa/Cocoa.h>
#import "CeltxImport.h"
#import "HTMLParser.h"
#import <UnzipKit/UnzipKit.h>

#define TITLE @"Import .celtx File"
#define PADDING 8.0
#define WIDTH 300
#define SCRIPT_PREFIX @"script-"

#import <os/log.h>

@interface CeltxImport ()
@property (nonatomic) UZKArchive *container;
@property (nonatomic) NSMutableDictionary *scriptData;
@property (nonatomic) NSMutableArray *scripts;
@property (nonatomic) NSMutableArray *currentDocument;
@property (nonatomic) NSWindowController *dialogController;
@property (nonatomic) NSPopUpButton *scriptSelect;
@end

@implementation CeltxImport

- (instancetype)initWithURL:(NSURL*)url {
	self = [super init];
	
	if (self) {
		bool fileIsZip = [UZKArchive urlIsAZip:url];
		
		if (fileIsZip) {
			// Legacy Celtx file
			[self readContainerAt:url];
		} else {
			// Modern Celtx file
			[self readSingleScreenplayAt:url];
		}
	}
	
	return self;
}

- (void)readSingleScreenplayAt:(NSURL*)url {
	NSLog(@"reading single...");
	
	NSData *data = [NSData dataWithContentsOfURL:url];
	NSLog(@"DATA: %@", data);
	
	NSDictionary *screenplay = [self parseContents:data];
	
	self.script = screenplay[@"screenplay"];
	NSLog(@"screenplay %@", screenplay);
}

- (void)readContainerAt:(NSURL*)url {
	NSError *error;
	
	// Init scripts & zip container
	_scriptData = [NSMutableDictionary dictionary];
	_container = [[UZKArchive alloc] initWithURL:url error:&error];

	if (error) os_log(OS_LOG_DEFAULT, "Celtx import: Error unarchiving file '%@'", url.lastPathComponent);
	if (!_container) return;
	
	// Gather the data
	NSArray<NSString*> *filesInArchive = [_container listFilenames:&error];
	for (NSString *string in filesInArchive) {
		// We only gather the ones which are SCRIPTS
		if ([string rangeOfString:SCRIPT_PREFIX].location != NSNotFound) {
			NSData *scriptData = [_container extractDataFromFile:string error:&error];
			[_scriptData setValue:scriptData forKey:string];
		}
	}
	
	// Fetch the HTML
	NSMutableArray *scriptData = [NSMutableArray array];
	for (id key in _scriptData) {
		NSData *data = _scriptData[key];
		[scriptData addObject:data];
	}
	
	// Parse XML files
	[self parseScripts:scriptData];
	
	[self scriptSelectionDialog];
}

- (void)scriptSelectionDialog {
	NSWindow *dialog = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WIDTH, 120) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	dialog.title = TITLE;
	
	dialog.contentView = [[NSView alloc] initWithFrame:dialog.frame];
	
	[dialog.contentView addSubview:[self createCloseButton]];
	[dialog.contentView addSubview:[self createOpenButton]];
	[dialog.contentView addSubview:[self createDocumentList]];
	[dialog.contentView addSubview:[self createLabel]];
	
	_dialogController = [[NSWindowController alloc] initWithWindow:dialog];
	[NSApp runModalForWindow:_dialogController.window];
}

- (NSTextField*)createLabel {
	NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(PADDING, 68, WIDTH - PADDING * 2, 40)];
	label.bezeled = NO;
	label.drawsBackground = NO;
	label.editable = NO;
	label.selectable = NO;
	label.lineBreakMode = NSLineBreakByWordWrapping;
	
	label.stringValue = @"This document contains multiple screenplays.\nSelect which one you would prefer to import.";
	
	return  label;;
}

- (NSButton*)createCloseButton {
	NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(PADDING, PADDING, 70, 30)];
	cancelButton.title = @"Cancel";
	cancelButton.bezelStyle = NSRoundedBezelStyle;
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(closeModal)];
	return cancelButton;
}
- (NSButton*)createOpenButton {
	NSButton *openButton = [[NSButton alloc] initWithFrame:NSMakeRect(210, PADDING, 80, 30)];
	openButton.title = @"Open";
	openButton.bezelStyle = NSRoundedBezelStyle;
	[openButton setTarget:self];
	[openButton setAction:@selector(openDocuments)];
	return openButton;
}

- (NSPopUpButton*)createDocumentList {
	NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(PADDING, 40, WIDTH - PADDING * 2, 30)];
	
	for (NSDictionary *script in _scripts) {
		[button addItemWithTitle:script[@"title"]];
	}
	
	_scriptSelect = button;
	return button;
}

#pragma mark - Dialog open & close selectors

- (void)closeModal {
	[_dialogController close];
	[NSApp stopModal];
}
- (void)openDocuments {
	NSInteger index = [_scriptSelect.itemArray indexOfObject:_scriptSelect.selectedItem];
	NSDictionary *script = _scripts[index];
	
	// Set selected script
	_script = script[@"screenplay"];
	
	[_dialogController close];
	[NSApp stopModal];
}


#pragma mark - Opening the container

- (void)parseScripts:(NSArray*)scripts {
	_scripts = [NSMutableArray array];
	
	for (NSData *data in scripts) {
		NSDictionary *script = [self parseContents:data];
		[_scripts addObject:script];
	}
}

- (NSDictionary*)parseContents:(NSData*)data {
	NSError *error;
	NSMutableString *screenplay = [NSMutableString string];
	HTMLParser *parser = [HTMLParser.alloc initWithData:data error:&error];
	
	HTMLNode *htmlNode = [parser html];
	NSString *title = [htmlNode findChildWithTag:@"title"].allContents;
	
	HTMLNode *bodyNode = [parser body];
	NSArray *paragraphs = [bodyNode findChildrenWithTag:@"p"];
	
	NSString *previousType;
	
	for (HTMLNode *node in paragraphs) {
		NSString *contents = [self contentsFor:node previousType:previousType];
		[screenplay appendString:contents];
		
		previousType = node.className;;
	}
	
	// Remove dual line breaks
	[screenplay replaceOccurrencesOfString:@"\n\n\n" withString:@"\n\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, screenplay.length)];
	
	// Add whole text to the dictionary
	if (screenplay.length) {
		return @{ @"title": (title.length) ? title : @"", @"screenplay": screenplay };
	} else {
		return nil;
	}
}

- (NSString*)contentsFor:(HTMLNode*)node previousType:(NSString*)previousType {
	// Types are stored as paragraph classes
	NSString *type = node.className;
	
	// Replace line breaks
	NSString *contents = [node.allContents stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		
	// Add the correct amount of spacing
	if ([type isEqualToString:@"character"]) {
		contents = [NSString stringWithFormat:@"\n%@\n", contents.uppercaseString];
	}
	else if ([type isEqualToString:@"sceneheading"]) {
		if ([self shouldForceTitle:contents]) {
			contents = [NSString stringWithFormat:@"\n.%@\n\n", contents];
		} else {
			contents = [NSString stringWithFormat:@"\n%@\n\n", contents.uppercaseString];
		}
	}
	else if ([type isEqualToString:@"dialog"] || [type isEqualToString:@"parenthetical"]) {
		contents = [NSString stringWithFormat:@"%@\n", contents];
	} else {
		if ([previousType isEqualToString:@"dialog"]) contents = [NSString stringWithFormat:@"\n%@", contents];
		contents = [NSString stringWithFormat:@"%@\n\n", contents];
	}
	
	return contents;
}

- (bool)shouldForceTitle:(NSString*)string {
	// Under 3 characters we will always force it
	if (string.length < 3) return YES;
	
	bool isTitle = NO;
	string = string.lowercaseString;
		
	if ([[string substringToIndex:3] isEqualToString:@"int"]) isTitle = YES;
	if ([[string substringToIndex:3] isEqualToString:@"ext"]) isTitle = YES;
	if ([[string substringToIndex:5] isEqualToString:@"i./e."]) isTitle = YES;
	
	return !isTitle;
}

@end
