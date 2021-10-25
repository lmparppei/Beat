//
//  BeatTitlePageEditor.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.5.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatTitlePageEditor.h"
#import "NSString+CharacterControl.h"

@interface BeatTitlePageEditor ()
@property (weak) IBOutlet NSTextField *titleField;
@property (weak) IBOutlet NSTextField *creditField;
@property (weak) IBOutlet NSTextField *authorField;
@property (weak) IBOutlet NSTextField *sourceField;
@property (weak) IBOutlet NSTextField *dateField;
@property (weak) IBOutlet NSTextField *contactField;
@property (weak) IBOutlet NSTextField *notesField;

@property (weak) IBOutlet NSTextField *previewTitle;
@property (weak) IBOutlet NSTextField *previewContact;
@property (weak) IBOutlet NSTextField *previewDate;

@property (nonatomic) NSMutableArray *customFields;
@property (assign) id<BeatEditorDelegate> editorDelegate;
@property (nonatomic) ContinuousFountainParser *parser;
@end

@implementation BeatTitlePageEditor

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate {
	self = [super initWithWindowNibName:@"BeatTitlePageEditor" owner:self];
	self.editorDelegate = delegate;
	
	return self;
}

- (void)parseTitlePage {
	ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initWithString:[self.editorDelegate getText]];

	// List of applicable fields
	NSDictionary* fields = @{
							 @"title":_titleField,
							 @"credit":_creditField,
							 @"author":_authorField,
							 @"authors":_authorField, // override if "authors" is present
							 @"source":_sourceField,
							 @"draft date":_dateField,
							 @"contact":_contactField,
							 @"notes":_notesField
							 };

	// Clear custom fields
	_customFields = [NSMutableArray array];
	
	if (parser.titlePage.count > 0) {
		// This is a shitty approach, but what can I say. When copying the dictionary, the order of entries gets messed up, so we need to uh...
		for (NSDictionary *dict in parser.titlePage) {
			NSString *key = [dict.allKeys objectAtIndex:0];
			
			if ([fields objectForKey:key]) {
				NSMutableString *values = [NSMutableString string];
				
				for (NSString *val in dict[key]) {
					if ([dict[key] indexOfObject:val] == [dict[key] count] - 1) [values appendFormat:@"%@", val];
					else [values appendFormat:@"%@\n", val];
				}
				
				// Strip extra line break from multiline values
				if (values.length > 1 && [values characterAtIndex:0] == '\n') [values setString:[values substringFromIndex:1]];
				
				if (![fields[key] isKindOfClass:[NSTextView class]]) [fields[key] setStringValue:values];
				else [fields[key] setString:values];
			} else {
				[_customFields addObject:dict];
			}
		}
	} else {
		// Clear all fields
		for (NSString *key in fields) {
			[fields[key] setStringValue:@""];
		}
	}
}

- (void)windowDidLoad {
    [super windowDidLoad];
	[self parseTitlePage];
	[self fieldDidChange:nil];
}

- (BOOL)control:(NSControl*)control textView:(nonnull NSTextView *)textView doCommandBySelector:(nonnull SEL)commandSelector {
	BOOL result = NO;
	
	[control action];
	
	if (commandSelector == @selector(insertNewline:))
	{
		// Don't allow line break on single-line field
		if (control.lineBreakMode == NSLineBreakByClipping) {
			return NO;
		}
		
		// Else add line break
		[textView insertNewlineIgnoringFieldEditor:self];
		result = YES;
	}
	
	return result;
}

- (IBAction)close:(id)sender {
	[self.window.sheetParent endSheet:self.window];
}

- (IBAction)applyTitlePageEdit:(id)sender {
	NSMutableString *titlePage = [NSMutableString string];
	
	// BTW, isn't Objective C nice, beautiful and elegant?
	[titlePage appendFormat:@"Title: %@\n", [_titleField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Credit: %@\n", [_creditField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Author: %@\n", [_authorField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Source: %@\n", [_sourceField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Draft date: %@\n", [_dateField.stringValue  stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	
	// Only add contact + notes fields they are not empty
	NSString *contact = [_contactField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	if ([contact length] > 0) [titlePage appendFormat:@"Contact:\n%@\n", contact];
	
	NSString *notes = [_notesField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	if ([notes length] > 0) [titlePage appendFormat:@"Notes:\n%@\n", notes];
	
	// Add back possible custom fields that were left out
	for (NSDictionary *dict in _customFields) {
		NSString *key = [dict.allKeys objectAtIndex:0];
		NSArray *obj = dict[key];
	
		// Check if it is a text block or single line
		if ([obj count] == 1) [titlePage appendFormat:@"%@:", [key capitalizedString]];
		else  [titlePage appendFormat:@"%@:\n", [key capitalizedString]];
		
		for (NSString *val in obj) {
			[titlePage appendFormat:@"%@\n", val];
		}
	}
	
	_result = titlePage;
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)fieldDidChange:(id)sender {
	NSLog(@"did change");
	
	NSString *title = _titleField.stringValue;
	if (_creditField.stringValue.length) title = [title stringByAppendingFormat:@"\n\n%@", _creditField.stringValue];
	if (_authorField.stringValue.length) title = [title stringByAppendingFormat:@"\n\n%@", _authorField.stringValue];
	if (_sourceField.stringValue.length) title = [title stringByAppendingFormat:@"\n\n\n%@", _sourceField.stringValue];
	
	[_previewTitle setStringValue:title];

	NSString *info = [_contactField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	if (_notesField.stringValue.length) info = [info stringByAppendingFormat:@"\n\n%@", [_notesField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	
	[_previewContact setStringValue:info];

	[_previewDate setStringValue:_dateField.stringValue];
}

@end
/*
 
 ole minulle sisko
 ole minulle sisko
 jota ei koskaan ollut
 johdata turvallisesti kotiin
 
 */
