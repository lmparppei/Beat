//
//  BeatPreferencesPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPreferencesPanel.h"
#import "BeatUserDefaults.h"
#import "Document.h"
#import "BeatModalInput.h"

//#define HEADING_SAMPLE @"INT. SCENE - DAY"

@interface BeatPreferencesPanel () <NSTextFieldDelegate>
@property (nonatomic) NSArray* validationItems;

@property (nonatomic, weak) IBOutlet NSButton *hideFountainMarkup;
@property (nonatomic, weak) IBOutlet NSButton *showSceneNumberLabels;
@property (nonatomic, weak) IBOutlet NSButton *showPageNumbers;
@property (nonatomic, weak) IBOutlet NSButton *matchParentheses;
@property (nonatomic, weak) IBOutlet NSButton *automaticContd;
@property (nonatomic, weak) IBOutlet NSButton *autoLineBreaks;
@property (nonatomic, weak) IBOutlet NSButton *autocomplete;
@property (nonatomic, weak) IBOutlet NSButton *showMarkersInScrollbar;

@property (nonatomic, weak) IBOutlet NSPopUpButton *useSansSerif;
@property (nonatomic, weak) IBOutlet NSPopUpButton *defaultPageSize;
@property (nonatomic, weak) IBOutlet NSPopUpButton *language;

@property (nonatomic, weak) IBOutlet NSButton *headingStyleBold;
@property (nonatomic, weak) IBOutlet NSButton *headingStyleUnderline;

@property (nonatomic, weak) IBOutlet NSButton *headingSpacing1;
@property (nonatomic, weak) IBOutlet NSButton *headingSpacing2;

@property (nonatomic, weak) IBOutlet NSTextField *sampleHeading;

@property (nonatomic, weak) IBOutlet NSTextField *screenplayItemContd;
@property (nonatomic, weak) IBOutlet NSTextField *screenplayItemMore;

@property (nonatomic) NSMutableDictionary *controls;

@property (weak) IBOutlet NSTabView *tabView;

@property (nonatomic) NSMutableDictionary *locales;

@property (nonatomic) NSString *headingSample;

@end

@implementation BeatPreferencesPanel

- (instancetype) init {
	return [super initWithWindowNibName:self.className owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	// Get user default names
	NSDictionary *userDefaults = BeatUserDefaults.userDefaults;
	
	_controls = NSMutableDictionary.new;
	_locales = NSMutableDictionary.new;
	
	for (NSString *key in userDefaults.allKeys) {
		if ([self valueForKey:key]) {
			// Find an object in the NIB by the name of this value
			id item = [self valueForKey:key];
			
			// Add control into dictionary by the default name
			[_controls setValue:item forKey:key];
			
			// Check control type
			if ([item isKindOfClass:NSPopUpButton.class]) {
				// We need to check for subclasses of NSButton first
				NSPopUpButton *button = item;
				NSInteger value = [BeatUserDefaults.sharedDefaults getInteger:key];
				[button selectItem:button.itemArray[value]];
			}
			else if ([item isKindOfClass:NSButton.class]) {
				NSButton *button = item;
				bool value = [BeatUserDefaults.sharedDefaults getBool:key];
				
				if (value) button.state = NSOnState;
				else button.state = NSOffState;
			}
			else if ([item isKindOfClass:NSTextField.class]) {
				NSTextField *textField = item;
				NSString *value = [BeatUserDefaults.sharedDefaults get:key];
				
				textField.delegate = self;
				textField.stringValue = value;
			}
		} else {
			
			if ([key isEqualToString:@"sceneHeadingSpacing"]) {
				NSInteger value = [BeatUserDefaults.sharedDefaults getInteger:key];
				if (value == 1) _headingSpacing1.state = NSOnState;
				else _headingSpacing2.state = NSOnState;
			}
			
		}
	}
	
	[self setupLanguages];
	
	[self.window.toolbar setSelectedItemIdentifier:@"General"];
	[self updateHeadingSample:YES];
}

- (NSString*)keyForControl:(id)control {
	for (NSString* key in _controls.allKeys) {
		if (_controls[key] == control) return key;
	}
	
	return nil;
}

- (void)setupLanguages {
	NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject;
	
	[_language removeAllItems];
	
	for (NSString *loc in NSBundle.mainBundle.localizations) {
		if ([loc isEqualToString:@"Base"]) continue;

		NSLocale *locale = [NSLocale localeWithLocaleIdentifier:loc];
		NSString *name = [locale displayNameForKey:NSLocaleIdentifier value:loc];
		
		[_locales setValue:loc forKey:name];
		[_language addItemWithTitle:name];
		
		// Select current language
		if ([loc isEqualToString:language]) [_language selectItem:_language.itemArray.lastObject];
	}
}

- (void)updateHeadingSample {
	[self updateHeadingSample:NO];
}
- (void)updateHeadingSample:(bool)windowDidLoad {
	if (!_headingSample) _headingSample = self.sampleHeading.stringValue.copy;
	
	NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:_headingSample];
	
	// Add line break for spacing 2
	if (_headingSpacing2.state == NSOnState) attrStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", _headingSample]];

	if (_headingStyleBold.state == NSOnState) {
		self.sampleHeading.font = [NSFont fontWithName:@"Courier Prime Bold" size:self.sampleHeading.font.pointSize];
		[attrStr addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Courier Prime Bold" size:self.sampleHeading.font.pointSize] range:(NSRange){0,attrStr.length}];
	} else {
		[attrStr addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Courier Prime" size:self.sampleHeading.font.pointSize] range:(NSRange){0,attrStr.length}];
	}
	if (_headingStyleUnderline.state == NSOnState) {
		[attrStr addAttribute:NSUnderlineStyleAttributeName value:@1 range:(NSRange){0,attrStr.length}];
	} else {
		[attrStr addAttribute:NSUnderlineStyleAttributeName value:@0 range:(NSRange){0,attrStr.length}];
	}
	[attrStr addAttribute:NSForegroundColorAttributeName value:NSColor.blackColor range:(NSRange){0,attrStr.length}];

	[self.sampleHeading setAttributedStringValue:attrStr];
	
	// Invalidate previews for all documents when layout settings are changed
	if (!windowDidLoad) {
		for (Document *doc in NSDocumentController.sharedDocumentController.documents) {
			[doc invalidatePreview];
		}
	}
}
- (void)show {
	[self showWindow:self.window];
	[self.window makeKeyAndOrderFront:self.window];

//	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//		[NSApplication.sharedApplication runModalForWindow:self.window];
//	});
}

- (IBAction)toggleHeadingSpacing:(id)sender {
	if (sender == _headingSpacing1) [BeatUserDefaults.sharedDefaults saveInteger:1 forKey:@"sceneHeadingSpacing"];
	else if (sender == _headingSpacing2) [BeatUserDefaults.sharedDefaults saveInteger:2 forKey:@"sceneHeadingSpacing"];
	[self updateHeadingSample];
}

- (IBAction)toggle:(id)sender {
	for (NSString* key in _controls.allKeys) {
		id control = _controls[key];
		
		if (sender == control) {
			if ([sender isKindOfClass:NSPopUpButton.class]) {
				// Dropdown
				NSPopUpButton *button = sender;
				[BeatUserDefaults.sharedDefaults saveInteger:[button.itemArray indexOfObject:button.selectedItem] forKey:key];
			}
			else if ([sender isKindOfClass:NSButton.class]) {
				// Button
				NSButton *button = sender;
				if (button.state == NSOnState) {
					[BeatUserDefaults.sharedDefaults saveBool:YES forKey:key];
				} else {
					[BeatUserDefaults.sharedDefaults saveBool:NO forKey:key];
				}
			}
			else if ([sender isKindOfClass:NSTextField.class]) {
				// Text field
				NSTextField *textField = sender;
				
				NSString *currentValue = [BeatUserDefaults.sharedDefaults get:key];
				NSString *newValue = [textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
				NSString *defaultValue = [BeatUserDefaults.sharedDefaults defaultValueFor:key];
				
				// Get default value if the string is empty
				if (newValue.length == 0) {
					newValue = defaultValue;
				}
				
				// If the value is equal to default value, remove it, because we might
				// want to change the default at some point in the future.
				if ([newValue isEqualToString:defaultValue]) {
					[BeatUserDefaults.sharedDefaults save:@"" forKey:key];
				}
				else if (![newValue isEqualToString:currentValue]) {
					[BeatUserDefaults.sharedDefaults save:newValue forKey:key];
				}
			}
		}
	}
	
	if (sender == _headingStyleBold || sender == _headingStyleUnderline) [self updateHeadingSample];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc applyUserSettings];
	}
}

- (IBAction)toggleLanguage:(id)sender {
	NSPopUpButton *btn = sender;
	
	// Get selected locale
	NSString* selected = btn.selectedItem.title;
	NSString* locale = _locales[selected];
	
	// Store into user defaults
	NSArray *langs = @[locale, @"en"];
	[NSUserDefaults.standardUserDefaults setValue:langs forKey:@"AppleLanguages"];
	
	// Show an alert with the SELECTED LOCALE about the need to restart the app
	NSString *localePath = [NSBundle.mainBundle pathForResource:locale ofType:@"lproj"];
	NSBundle *localeBundle = [NSBundle bundleWithPath:localePath];
	
	NSString *message = [localeBundle localizedStringForKey:@"language.alert" value:nil table:nil];
	NSString *informative = [localeBundle localizedStringForKey:@"language.informative" value:nil table:nil];
	
	// Display modal
	NSAlert *alert = [NSAlert.alloc init];
	alert.messageText = message;
	alert.informativeText = informative;
	[alert runModal];
}

- (IBAction)toggleTab:(id)sender {
	NSToolbarItem *button = sender;
	NSToolbar *toolbar = button.toolbar;
	
	NSInteger i = [toolbar.items indexOfObject:button];
	NSTabViewItem * item = [self.tabView tabViewItemAtIndex:i];
	
	[self.tabView selectTabViewItem:item];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[NSApplication sharedApplication] stopModal];
}

-(id)valueForUndefinedKey:(NSString *)key {
	return nil;
}

- (void)setCheckBox:(NSString*)name value:(bool)value {
	NSButton *button = [self valueForKey:name];
	
	if (value) button.state = NSOnState;
	else button.state = NSOffState;
}

#pragma mark - Text field delegation

-(void)controlTextDidChange:(NSNotification *)obj {
	NSTextField *textField = obj.object;
	
	// Make contents uppercase
	NSRange selectedRange = textField.currentEditor.selectedRange;
	textField.stringValue = textField.stringValue.uppercaseString;
		
	textField.currentEditor.selectedRange = selectedRange;
	
	[self toggle:textField];
}
- (void)controlTextDidEndEditing:(NSNotification *)obj {
	NSTextField *textField = obj.object;
	
	// Read default value when the string value is empty
	if (textField.stringValue.length == 0) {
		NSString *key = [self keyForControl:textField];
		NSString *defaultValue = [BeatUserDefaults.sharedDefaults defaultValueFor:key];
		textField.stringValue = defaultValue;
	}
}

@end
/*
 
 the garden's heart has swollen
 under the sun,
 and the garden mind is slowly
 being emptied of green memories.
 
 */
