//
//  BeatPreferencesPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 TODO: Rewrite this class. It's currently working in a very backwards logic.
 
 */

#import "BeatPreferencesPanel.h"
#import "Document.h"
#import "BeatModalInput.h"
#import "Beat-Swift.h"
#import <BeatCore/BeatCore.h>


@interface BeatPreferencesPanel () <NSTextFieldDelegate>
@property (nonatomic) NSArray* validationItems;

@property (nonatomic, weak) IBOutlet NSButton *hideFountainMarkup;
@property (nonatomic, weak) IBOutlet NSButton *showSceneNumberLabels;
@property (nonatomic, weak) IBOutlet NSButton *showPageNumbers;
@property (nonatomic, weak) IBOutlet NSButton *showPageSeparators;
@property (nonatomic, weak) IBOutlet NSButton *matchParentheses;
@property (nonatomic, weak) IBOutlet NSButton *automaticContd;
@property (nonatomic, weak) IBOutlet NSButton *autoLineBreaks;
@property (nonatomic, weak) IBOutlet NSButton *autocomplete;
@property (nonatomic, weak) IBOutlet NSButton *showMarkersInScrollbar;

@property (nonatomic, weak) IBOutlet NSPopUpButton *fontStyle;
@property (nonatomic, weak) IBOutlet NSPopUpButton *defaultPageSize;
@property (nonatomic, weak) IBOutlet NSPopUpButton *language;
@property (nonatomic, weak) IBOutlet NSPopUpButton *outlineFontSizeModifier;

@property (nonatomic, weak) IBOutlet NSButton *headingSpacing1;
@property (nonatomic, weak) IBOutlet NSButton *headingSpacing2;

@property (nonatomic, weak) IBOutlet NSTextView *sampleScene;

@property (nonatomic, weak) IBOutlet NSTextField *screenplayItemContd;
@property (nonatomic, weak) IBOutlet NSTextField *screenplayItemMore;

@property (nonatomic, weak) IBOutlet NSTextField *backupURLdisplay;
@property (nonatomic, weak) IBOutlet NSButton *backupUseDefault;
@property (nonatomic, weak) IBOutlet NSButton *backupUseCustom;

@property (nonatomic, weak) IBOutlet NSButton *updatePluginsAutomatically;

@property (nonatomic, weak) IBOutlet NSButton *sectionFontTypeSansSerif;
@property (nonatomic, weak) IBOutlet NSButton *sectionFontTypeSerif;
@property (nonatomic, weak) IBOutlet NSPopUpButton *sectionFontSizeMenu;
@property (nonatomic, weak) IBOutlet NSButton *synopsisFontTypeSansSerif;
@property (nonatomic, weak) IBOutlet NSButton *synopsisFontTypeSerif;

@property (nonatomic, weak) IBOutlet NSButton *actionPaginationDefault;
@property (nonatomic, weak) IBOutlet NSButton *actionPaginationAvoid;

@property (nonatomic) NSMutableDictionary *controls;

@property (weak) IBOutlet NSTabView *tabView;

@property (nonatomic) NSMutableDictionary *locales;

@property (nonatomic) NSString *headingSample;

@property (nonatomic, weak) IBOutlet NSPopUpButton* novelFontStyle;
@property (nonatomic, weak) IBOutlet NSImageView* screenplayFontWarning;
@property (nonatomic) NSString* activeFontSettingKey;
@property (nonatomic) bool activeFontRequiresMonospaced;

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
	
	// Iterate through user default keys and find the property by that name. This is a bit shady, but works.
	// For example: "showSceneNumbers" -> @IBOutlet NSButton* showSceneNumbers
	// If you want to skip this behavior, see the else clause
	for (NSString *key in userDefaults.allKeys) {
		if ([self valueForKey:key]) {
			// Find the property by the name of this value
			id item = [self valueForKey:key];
			// Check that the property is a control, otherwise we'll carry on.
			if (![item isKindOfClass:NSControl.class]) continue;
			
			// Add the control into dictionary (with the property name as its key)
			[_controls setValue:item forKey:key];
			
			// Check control type
			if ([item isKindOfClass:NSPopUpButton.class]) {
				// We need to check for subclasses of NSButton first
				NSPopUpButton *button = item;
				NSInteger value = [BeatUserDefaults.sharedDefaults getInteger:key];
				if (value >= button.itemArray.count) value = 0;
				
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
			else if ([key isEqualToString:BeatSettingBackupURL]) {
				NSString* url = [BeatUserDefaults.sharedDefaults get:BeatSettingBackupURL];
				
				if (url.length == 0) self.backupUseDefault.state = NSOnState;
				else self.backupUseCustom.state = NSOnState;
					
					
				self.backupURLdisplay.stringValue = url;
			}
			else if ([key isEqualToString:@"sectionFontType"]) {
				NSString* value = [BeatUserDefaults.sharedDefaults get:key];
				if (![value isEqualToString:@"system"]) self.sectionFontTypeSerif.state = NSControlStateValueOn;
				else self.sectionFontTypeSansSerif.state = NSControlStateValueOn;
			}
			else if ([key isEqualToString:@"sectionFontSize"]) {
				CGFloat value = [BeatUserDefaults.sharedDefaults getFloat:key];
				for (BeatMenuItemWithFloat* item in self.sectionFontSizeMenu.menu.itemArray) {
					if ((CGFloat)item.floatValue == value) {
						[self.sectionFontSizeMenu selectItem:item];
						break;
					}
				}
			}
			else if ([key isEqualToString:BeatSettingSynopsisFontType]) {
				NSString* value = [BeatUserDefaults.sharedDefaults get:key];
				if (![value isEqualToString:@"system"]) self.synopsisFontTypeSerif.state = NSControlStateValueOn;
				else self.synopsisFontTypeSansSerif.state = NSControlStateValueOn;
			}
			else if ([key isEqualToString:BeatSettingParagraphPaginationMode]) {
				NSInteger value = [BeatUserDefaults.sharedDefaults getInteger:BeatSettingParagraphPaginationMode];
				if (value == 0) self.actionPaginationDefault.state = NSControlStateValueOn;
				else self.actionPaginationAvoid.state = NSControlStateValueOn;
			}
		}
	}
	
	 
	[self setupLanguages];
	[self migrateLegacyCustomFonts];
	[self updateFontPopups];

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

- (void)updateHeadingSample:(bool)windowDidLoad
{
	// Parse some sample text (this could be localized as well!)
	NSString* sample = @"A moment's silence. Ansa nods, even smiles. Only a little, but even that is enough to nourish Holappa's withered soul.\n\nINT. CAFÉ - DAY #23#\n\nAn old-fashioned café. Holappa stirs his coffee. He doesn't seem like a smooth operator, because he says nothing.\n\n!!SHOT:\nOutside, leaves are falling from the trees.";
	ContinuousFountainParser* parser = [ContinuousFountainParser.alloc initWithString:sample];
	[parser updateOutline];
	
	// Force reloading of current default stylesheet
	[BeatStyles.shared.defaultStyles reloadWithDocumentSettings:nil];
	BeatExportSettings* settings = BeatExportSettings.new;
	settings.printSceneNumbers = true;
	
	// Create a renderer
	BeatRenderer* renderer = [BeatRenderer.alloc initWithSettings:settings];
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	
	// Render the given lines (I mean how amazing is it that my APIs and objects actually are this flexible? Who would have thought.)
	for (Line* line in parser.preprocessForPrinting) {
		if (line.type == empty) continue;
		NSAttributedString* str = [renderer renderLine:line];
		[attrStr appendAttributedString:str];
	}
	
	// Set sample value (and adjust some text view settings as well)
	self.sampleScene.linkTextAttributes = @{};
	self.sampleScene.displaysLinkToolTips = false;
	self.sampleScene.textContainer.lineFragmentPadding = 0.0;
	self.sampleScene.textContainerInset = NSMakeSize(0, 0);
	self.sampleScene.enclosingScrollView.hasVerticalScroller = false;
	self.sampleScene.enclosingScrollView.hasHorizontalScroller = false;
		
	[self.sampleScene.textStorage setAttributedString:attrStr];
}

- (void)reloadStyles
{
	for (id<BeatEditorDelegate>editor in NSDocumentController.sharedDocumentController.documents) {
		[editor reloadStyles];
	}
}

- (void)show
{
	[self showWindow:self.window];
	[self.window makeKeyAndOrderFront:self.window];
}

- (IBAction)toggleHeadingSpacing:(id)sender {
	if (sender == _headingSpacing1) [BeatUserDefaults.sharedDefaults saveInteger:1 forKey:@"sceneHeadingSpacing"];
	else if (sender == _headingSpacing2) [BeatUserDefaults.sharedDefaults saveInteger:2 forKey:@"sceneHeadingSpacing"];
	
	[self reloadStyles];
	
	[self updateHeadingSample];
}

- (IBAction)toggleBackupLocation:(id)sender {
	NSButton* b = sender;
	if ([b.identifier isEqualToString:@"default"]) [BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingBackupURL];
	else {
		if (self.backupURLdisplay.stringValue.length > 0) {
			[BeatUserDefaults.sharedDefaults save:self.backupURLdisplay.stringValue forKey:BeatSettingBackupURL];
		} else {
			[self selectBackupLocation:nil];
		}
	}
}

/// The modern way of setting values. Migrate all checkboxes to use this.
- (IBAction)toggleUserSetting:(BeatUserDefaultCheckbox*)sender
{
	if (sender.userDefaultKey.length == 0) {
		NSLog(@"WARNING: No user default key set for %@", sender);
		return;
	}
	
	[BeatUserDefaults.sharedDefaults saveBool:(sender.state == NSOnState) forKey:sender.userDefaultKey];
	
	if (sender.resetPreview) {
		[self reloadStyles];
		[self updateHeadingSample];
	}
	
	[self apply];
}

- (IBAction)selectOutlineFontSize:(id)sender {
	NSPopUpButton* button = sender;
	NSInteger modifier = button.indexOfSelectedItem;
	[BeatUserDefaults.sharedDefaults saveInteger:modifier forKey:BeatSettingOutlineFontSizeModifier];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc updateOutlineViews];
	}
}

- (IBAction)selectBackupLocation:(id)sender {
	NSOpenPanel* panel = NSOpenPanel.new;
	panel.canChooseFiles = false;
	panel.canChooseDirectories = true;
	panel.canCreateDirectories = true;
	
	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) return;
		
		// Access the bookmark
		id bookmark = [BeatBackup bookmarkBackupFolderWithUrl:panel.URL];
		if (bookmark) {
			[BeatUserDefaults.sharedDefaults save:panel.URL.path forKey:BeatSettingBackupURL];
			self.backupURLdisplay.stringValue = panel.URL.path;
		} else {
			[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingBackupURL];
		}
	}];
}

- (IBAction)toggle:(id)sender {
	for (NSString* key in _controls.allKeys) {
		id control = _controls[key];
		
		if (sender == control) {
			if ([sender isKindOfClass:NSPopUpButton.class]) {
				// Dropdown
				NSPopUpButton *button = sender;
				[BeatUserDefaults.sharedDefaults saveInteger:button.indexOfSelectedItem forKey:key];
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
				if (newValue.length == 0) newValue = defaultValue;
				
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
	
	if (sender == _screenplayItemMore || sender == _screenplayItemContd) [self reloadStyles];

	[self apply];
}

/// Only call this from `BeatUserDefaultCheckbox`
- (IBAction)toggleUserDefault:(BeatUserDefaultCheckbox*)sender
{
	bool value = (sender.state == NSOnState);
	[BeatUserDefaults.sharedDefaults save:@(value) forKey:sender.userDefaultKey];
}

- (IBAction)toggleSectionFontType:(NSButton*)sender
{
	NSString* value = (sender.tag == 0) ? @"system" : @"default";
	[BeatUserDefaults.sharedDefaults save:value forKey:BeatSettingSectionFontType];
	[self reloadStyles];
}

- (IBAction)selectSectionFontSize:(NSPopUpButton*)sender
{
	BeatMenuItemWithFloat* item = (BeatMenuItemWithFloat*)sender.selectedItem;
	[BeatUserDefaults.sharedDefaults saveFloat:item.floatValue forKey:BeatSettingSectionFontSize];
	[self reloadStyles];
}

- (IBAction)toggleSynopsisFontType:(NSButton*)sender
{
	NSString* value = (sender.tag == 0) ? @"system" : @"default";
	[BeatUserDefaults.sharedDefaults save:value forKey:BeatSettingSynopsisFontType];
	[self reloadStyles];
}

- (IBAction)toggleActionPagination:(NSButton*)sender
{
	[BeatUserDefaults.sharedDefaults save:@(sender.tag) forKey:BeatSettingParagraphPaginationMode];
	[self reloadStyles];
}

- (void)apply
{
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) [doc applyUserSettings];
}

#pragma mark - Custom fonts

static const NSInteger BeatScreenplayFontCustomTag = 3;
static const NSInteger BeatScreenplayFontChooseTag = 4;
static const NSInteger BeatNovelFontCustomTag = 1;
static const NSInteger BeatNovelFontChooseTag = 2;

- (IBAction)selectEditorFont:(NSPopUpButton*)sender
{
	if (sender.selectedItem.tag == BeatScreenplayFontCustomTag || sender.selectedItem.tag == BeatScreenplayFontChooseTag) {
		[self openFontPanelForSetting:BeatSettingCustomScreenplayFont requiresMonospaced:true];
	} else {
		[BeatUserDefaults.sharedDefaults saveInteger:sender.selectedItem.tag forKey:BeatSettingFontStyle];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomScreenplayFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomScreenplayEditorFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomScreenplayExportFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomEditorFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomExportFont];
		[self applyFontChanges];
	}
}

- (IBAction)selectNovelFont:(NSPopUpButton*)sender
{
	if (sender.selectedItem.tag == BeatNovelFontCustomTag || sender.selectedItem.tag == BeatNovelFontChooseTag) {
		[self openFontPanelForSetting:BeatSettingCustomNovelFont requiresMonospaced:false];
	} else {
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomNovelFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomNovelEditorFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomNovelExportFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomEditorFont];
		[BeatUserDefaults.sharedDefaults save:@"" forKey:BeatSettingCustomExportFont];
		[self applyFontChanges];
	}
}

- (void)openFontPanelForSetting:(NSString*)key requiresMonospaced:(bool)requiresMonospaced
{
	self.activeFontSettingKey = key;
	self.activeFontRequiresMonospaced = requiresMonospaced;

	NSFontManager* fm = NSFontManager.sharedFontManager;
	fm.target = self;
	fm.action = @selector(changeFont:);

	NSFont* current = [self fontForSetting:key];
	if (current == nil) current = requiresMonospaced ? [NSFont userFixedPitchFontOfSize:12.0] : [NSFont systemFontOfSize:12.0];

	[fm setSelectedFont:current isMultiple:NO];
	[fm orderFrontFontPanel:self];
	[self updateFontPopups];
}

- (NSFont*)fontForSetting:(NSString*)key
{
	NSString* name = [BeatUserDefaults.sharedDefaults get:key];
	if (name.length == 0) return nil;
	return [NSFont fontWithName:name size:12.0];
}

- (void)changeFont:(id)sender
{
	if (self.activeFontSettingKey == nil) return;

	NSFontManager* fm = (NSFontManager*)sender;
	NSFont* base = [self fontForSetting:self.activeFontSettingKey];
	if (base == nil) base = self.activeFontRequiresMonospaced ? [NSFont userFixedPitchFontOfSize:12.0] : [NSFont systemFontOfSize:12.0];

	NSFont* newFont = [fm convertFont:base];
	if (newFont == nil) return;

	[BeatUserDefaults.sharedDefaults save:newFont.fontName forKey:self.activeFontSettingKey];
	[self applyFontChanges];
}

- (void)applyFontChanges
{
	[self apply];
	[self reloadStyles];
	[self updateHeadingSample];
	[self updateFontPopups];
}

- (void)migrateLegacyCustomFonts
{
	NSString* screenplayFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomScreenplayFont];
	NSString* novelFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomNovelFont];

	NSString* editorFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomEditorFont];
	if (editorFont.length > 0 && screenplayFont.length == 0 && novelFont.length == 0) {
		[BeatUserDefaults.sharedDefaults save:editorFont forKey:BeatSettingCustomScreenplayFont];
		[BeatUserDefaults.sharedDefaults save:editorFont forKey:BeatSettingCustomNovelFont];
		screenplayFont = editorFont;
		novelFont = editorFont;
	}

	NSString* exportFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomExportFont];
	if (exportFont.length > 0 && screenplayFont.length == 0 && novelFont.length == 0) {
		[BeatUserDefaults.sharedDefaults save:exportFont forKey:BeatSettingCustomScreenplayFont];
		[BeatUserDefaults.sharedDefaults save:exportFont forKey:BeatSettingCustomNovelFont];
		screenplayFont = exportFont;
		novelFont = exportFont;
	}

	NSString* legacyScreenplayFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomScreenplayEditorFont];
	if (screenplayFont.length == 0 && legacyScreenplayFont.length > 0) {
		[BeatUserDefaults.sharedDefaults save:legacyScreenplayFont forKey:BeatSettingCustomScreenplayFont];
	}

	NSString* legacyNovelFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomNovelEditorFont];
	if (novelFont.length == 0 && legacyNovelFont.length > 0) {
		[BeatUserDefaults.sharedDefaults save:legacyNovelFont forKey:BeatSettingCustomNovelFont];
	}
}

- (void)updateFontPopups
{
	[self updateFontPopup:self.fontStyle customTag:BeatScreenplayFontCustomTag chooseTag:BeatScreenplayFontChooseTag setting:BeatSettingCustomScreenplayFont builtInTag:[BeatUserDefaults.sharedDefaults getInteger:BeatSettingFontStyle]];
	[self updateFontPopup:self.novelFontStyle customTag:BeatNovelFontCustomTag chooseTag:BeatNovelFontChooseTag setting:BeatSettingCustomNovelFont builtInTag:0];
	[self updateScreenplayFontWarning];
}

- (void)updateScreenplayFontWarning
{
	NSString* fontName = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomScreenplayFont];
	NSFont* font = (fontName.length > 0) ? [NSFont fontWithName:fontName size:12.0] : nil;
	bool showWarning = (font != nil && !font.isFixedPitch);

	self.screenplayFontWarning.hidden = !showWarning;
	self.screenplayFontWarning.toolTip = showWarning ? NSLocalizedString(@"prefs.font.notMonospaced", @"This font isn't monospaced, so page counts may differ from the standard.") : nil;
	if ([self.screenplayFontWarning respondsToSelector:@selector(setContentTintColor:)]) {
		self.screenplayFontWarning.contentTintColor = NSColor.systemYellowColor;
	}
}

- (void)updateFontPopup:(NSPopUpButton*)popup customTag:(NSInteger)customTag chooseTag:(NSInteger)chooseTag setting:(NSString*)setting builtInTag:(NSInteger)builtInTag
{
	popup.toolTip = nil;
	NSMenuItem* customItem = [popup.menu itemWithTag:customTag];
	NSMenuItem* chooseItem = [popup.menu itemWithTag:chooseTag];
	NSString* fontName = [BeatUserDefaults.sharedDefaults get:setting];

	if (fontName.length > 0) {
		NSFont* font = [NSFont fontWithName:fontName size:12.0];
		NSString* display = font.displayName ?: fontName;

		customItem.hidden = NO;
		customItem.title = display;
		chooseItem.title = NSLocalizedString(@"prefs.font.change", @"Change Font…");
		popup.toolTip = display;
		[popup selectItem:customItem];
		return;
	}

	customItem.hidden = YES;
	chooseItem.title = NSLocalizedString(@"prefs.font.choose", @"Choose Font…");

	NSMenuItem* builtIn = [popup.menu itemWithTag:builtInTag];
	if (builtIn != nil) [popup selectItem:builtIn];
	else [popup selectItemAtIndex:0];
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

	// Stop receiving font panel callbacks.
	NSFontManager* fm = NSFontManager.sharedFontManager;
	if (fm.target == self) {
		fm.target = nil;
		fm.action = NULL;
	}
	self.activeFontSettingKey = nil;
	if (NSFontPanel.sharedFontPanelExists) [NSFontPanel.sharedFontPanel orderOut:nil];
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
