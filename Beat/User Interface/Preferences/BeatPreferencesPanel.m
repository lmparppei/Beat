//
//  BeatPreferencesPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.9.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPreferencesPanel.h"
#import "BeatUserDefaults.h"
#import "Document.h"

@interface BeatPreferencesPanel ()
@property (nonatomic) NSArray* validationItems;

@property (nonatomic, weak) IBOutlet NSButton *hideFountainMarkup;
@property (nonatomic, weak) IBOutlet NSButton *showSceneNumberLabels;
@property (nonatomic, weak) IBOutlet NSButton *showPageNumbers;
@property (nonatomic, weak) IBOutlet NSButton *matchParentheses;
@property (nonatomic, weak) IBOutlet NSButton *autoLineBreaks;
@property (nonatomic, weak) IBOutlet NSButton *autocomplete;

@property (nonatomic, weak) IBOutlet NSPopUpButton *useSansSerif;
@property (nonatomic, weak) IBOutlet NSPopUpButton *defaultPageSize;

@property (nonatomic, weak) IBOutlet NSButton *headingStyleBold;
@property (nonatomic, weak) IBOutlet NSButton *headingStyleUnderline;

@property (nonatomic) NSMutableDictionary *controls;

@property (weak) IBOutlet NSTabView *tabView;

@end

@implementation BeatPreferencesPanel

- (instancetype) init {
	return [super initWithWindowNibName:self.className owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	// Get user default names
	NSDictionary *userDefaults = BeatUserDefaults.userDefaults;
	
	_controls = [NSMutableDictionary dictionary];
	
	for (NSString *key in userDefaults.allKeys) {
		if ([self valueForKey:key]) {
			id item = [self valueForKey:key];
			
			// Add control into dictionary
			[_controls setValue:item forKey:key];
			
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

- (IBAction)toggle:(id)sender {
	for (NSString* key in _controls.allKeys) {
		id control = _controls[key];
		
		if (sender == control) {
			if ([sender isKindOfClass:NSPopUpButton.class]) {
				NSPopUpButton *button = sender;
				NSLog(@"select %lu", [button.itemArray indexOfObject:button.selectedItem]);
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
		}
	}
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc applyUserSettings];
	}
}

- (IBAction)toggleTab:(id)sender {
	NSToolbarItem *button = sender;
	NSToolbar *toolbar = button.toolbar;
	
	NSInteger i = [toolbar.items indexOfObject:button];
	[self.tabView selectTabViewItem:[self.tabView tabViewItemAtIndex:i]];
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

@end
