//
//  BeatUserDefaults.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class aims to make life easier working with user defaults.
 userDefaults dictionary contains both the property name in DOCUMENT and in
 system user defaults, which, unfortunately, are not unified. I was young and silly.
 
 */

#import "BeatUserDefaults.h"

@implementation BeatUserDefaults

// Magnification
#define MAGNIFICATION_KEY @"magnification"
#define DEFAULT_MAGNIFICATION 1.5

// User preference key names for backwards compatibility
#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define SHOW_PAGE_NUMBERS_KEY @"Show Page Numbers"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"
#define DARKMODE_KEY @"Dark Mode"
#define AUTOMATIC_LINEBREAKS_KEY @"Automatic Line Breaks"
#define TYPEWRITER_KEY @"Typewriter Mode"
#define FONT_STYLE_KEY @"Sans Serif"
#define HIDE_FOUNTAIN_MARKUP_KEY @"Hide Fountain Markup"
#define AUTOSAVE_KEY @"Autosave"
#define AUTOCOMPLETE_KEY @"Autocomplete"

NSString* const BeatSettingMatchParentheses				= @"matchParentheses";

NSString* const BeatSettingShowPageNumbers 				= @"showPageNumbers";
NSString* const BeatSettingShowPageSeparators           = @"showPageSeparators";
NSString* const BeatSettingShowSceneNumbers 			= @"showSceneNumberLabels";

NSString* const BeatSettingAutosave 					= @"autosave";
NSString* const BeatSettingTypewriterMode 				= @"typewriterMode";
NSString* const BeatSettingHideFountainMarkup 			= @"hideFountainMarkup";
NSString* const BeatSettingAutocomplete 				= @"autocomplete";
NSString* const BeatSettingUseSansSerif 				= @"useSansSerif";
NSString* const BeatSettingMagnification 				= @"magnification";
NSString* const BeatSettingAutomaticLineBreaks 			= @"autoLineBreaks";
NSString* const BeatSettingUpdatePluginsAutomatically 	= @"updatePluginsAutomatically";
NSString* const BeatSettingBackupURL 					= @"backupURL";

NSString* const BeatSettingHeadingStyleBold 			= @"headingStyleBold";
NSString* const BeatSettingHeadingStyleUnderlined		= @"headingStyleUnderline";
NSString* const BeatSettingShotStyleBold                = @"shotStyleBold";
NSString* const BeatSettingShotStyleUnderlined          = @"shotStyleUnderline";
NSString* const BeatSettingDefaultPageSize 				= @"defaultPageSize";
NSString* const BeatSettingDisableFormatting 			= @"disableFormatting";
NSString* const BeatSettingShowMarkersInScrollbar 		= @"showMarkersInScrollbar";
NSString* const BeatSettingSceneHeadingSpacing 			= @"sceneHeadingSpacing";
NSString* const BeatSettingNovelLineSpacing             = @"novelLineSpacing";
NSString* const BeatSettingScreenplayItemMore 			= @"screenplayItemMore";
NSString* const BeatSettingScreenplayItemContd 			= @"screenplayItemContd";
NSString* const BeatSettingShowRevisions 				= @"showRevisions";
NSString* const BeatSettingShowRevisedTextColor         = @"showRevisedTextColor";
NSString* const BeatSettingShowTags	 					= @"showTags";
NSString* const BeatSettingAutomaticContd 				= @"automaticContd";

NSString* const BeatSettingShowHeadingsInOutline        = @"showHeadingsInOutline";
NSString* const BeatSettingShowSynopsisInOutline		= @"showSynopsisInOutline";
NSString* const BeatSettingShowSceneNumbersInOutline    = @"showSceneNumbersInOutline";
NSString* const BeatSettingShowNotesInOutline           = @"showNotesInOutline";
NSString* const BeatSettingShowMarkersInOutline         = @"showMarkersInOutline";
NSString* const BeatSettingShowSnapshotsInOutline       = @"showSnapshotsInOutline";

NSString* const BeatSettingFocusMode                    = @"focusMode";

NSString* const BeatSettingSuppressedAlert 				= @"suppressedAlerts";

NSString* const BeatSettingContinuousSpellChecking      = @"continuousSpellChecking";
NSString* const BeatSettingIgnoreSpellCheckingInDialogue = @"ignoreSpellCheckingInDialogue";

NSString* const BeatSettingOutlineSectionFontSize       = @"outlineSectionFontSize";
NSString* const BeatSettingOutlineSceneFontSize         = @"outlineSceneFontSize";
NSString* const BeatSettingOutlineSceneSynopsisFontSize = @"outlineSynopsisFontSize";

NSString* const BeatSettingOutlineFontSizeModifier      = @"outlineFontSizeModifier";
NSString* const BeatSettingNotepadZoom                  = @"notepadZoom";

NSString* const BeatSettingiOSShowWelcomeScreen         = @"showiOSWelcomeScreen";
NSString* const BeatSettingPhoneFontSize                = @"phoneFontSize";

NSString* const BeatSettingDarkMode                     = @"Dark Mode";
NSString* const BeatSettingLineTypeView                 = @"lineTypeView";

NSString* const BeatSettingSectionFontType              = @"sectionFontType";
NSString* const BeatSettingSectionFontSize              = @"sectionFontSize";
NSString* const BeatSettingSynopsisFontType             = @"synopsisFontType";

NSString* const BeatSettingAddTitlePageByDefault        = @"addTitlePageByDefault";

NSString* const BeatSettingRelativeOutlineHeights       = @"relativeOutlineHeights";

NSString* const BeatSettingParagraphPaginationMode      = @"paragraphPaginationMode";

NSString* const BeatSettingHideThumbnailView            = @"hideThumbnailView";


+ (BeatUserDefaults*)sharedDefaults
{
	static BeatUserDefaults* sharedDefaults;
	if (!sharedDefaults) {
		sharedDefaults = [[BeatUserDefaults alloc] init];
	}
	return sharedDefaults;
}

+ (NSDictionary*)userDefaults {
	// For the barbaric countries still using imperial units and non-standard paper sizes,
	// we'll set default-default paper size to US Letter (1)
	NSInteger pageSize = 0;
	NSString *language = NSLocale.currentLocale.localeIdentifier;
	if ([language isEqualToString:@"en_US"]) pageSize = 1;
	
	return @{
		// Structure: Document class property name, key, default
		BeatSettingMatchParentheses: @[MATCH_PARENTHESES_KEY, @YES],
		BeatSettingShowPageNumbers: @[SHOW_PAGE_NUMBERS_KEY, @YES],
		BeatSettingAutomaticLineBreaks: @[BeatSettingAutomaticLineBreaks, @YES],
		BeatSettingShowSceneNumbers: @[SHOW_SCENE_LABELS_KEY, @YES],
		BeatSettingHideFountainMarkup: @[HIDE_FOUNTAIN_MARKUP_KEY, @NO],
		BeatSettingTypewriterMode: @[TYPEWRITER_KEY, @NO],
		BeatSettingAutosave: @[AUTOSAVE_KEY, @NO],
		BeatSettingAutocomplete: @[AUTOCOMPLETE_KEY, @YES],
		BeatSettingUseSansSerif: @[FONT_STYLE_KEY, @NO],
        
        BeatSettingDarkMode: @[BeatSettingDarkMode, @NO],

		BeatSettingMagnification: @[BeatSettingMagnification, @(DEFAULT_MAGNIFICATION)],
		BeatSettingUpdatePluginsAutomatically: @[BeatSettingUpdatePluginsAutomatically, @YES],
		
        BeatSettingHeadingStyleBold: @[BeatSettingHeadingStyleBold, @YES],
		BeatSettingHeadingStyleUnderlined: @[BeatSettingHeadingStyleUnderlined, @NO],
        BeatSettingShotStyleBold: @[BeatSettingShotStyleBold, @YES],
        BeatSettingShotStyleUnderlined: @[BeatSettingShotStyleUnderlined, @NO],
    
		BeatSettingDefaultPageSize: @[BeatSettingDefaultPageSize, @(pageSize)],
		BeatSettingDisableFormatting: @[BeatSettingDisableFormatting, @NO],
		BeatSettingShowMarkersInScrollbar: @[BeatSettingShowMarkersInScrollbar, @NO],
		BeatSettingSceneHeadingSpacing: @[BeatSettingSceneHeadingSpacing, @2],
        BeatSettingNovelLineSpacing: @[BeatSettingNovelLineSpacing, @(2.0)],
		BeatSettingScreenplayItemMore: @[BeatSettingScreenplayItemMore, @"MORE"],
		BeatSettingScreenplayItemContd: @[BeatSettingScreenplayItemContd, @"CONT'D"],
		BeatSettingShowRevisions: @[BeatSettingShowRevisions, @YES],
        BeatSettingShowRevisedTextColor: @[BeatSettingShowRevisedTextColor, @NO],
		BeatSettingShowTags: @[BeatSettingShowTags, @YES],
		BeatSettingAutomaticContd: @[BeatSettingAutomaticContd, @YES],
        
        BeatSettingFocusMode: @[BeatSettingFocusMode, @(0)],
		
        BeatSettingShowHeadingsInOutline: @[BeatSettingShowHeadingsInOutline, @YES],
        BeatSettingShowSynopsisInOutline: @[BeatSettingShowSynopsisInOutline, @YES],
        BeatSettingShowSceneNumbersInOutline: @[BeatSettingShowSceneNumbersInOutline, @YES],
        BeatSettingShowNotesInOutline: @[BeatSettingShowNotesInOutline, @YES],
        BeatSettingShowMarkersInOutline: @[BeatSettingShowMarkersInOutline, @YES],
        BeatSettingShowSnapshotsInOutline: @[BeatSettingShowSnapshotsInOutline, @YES],
        
        BeatSettingContinuousSpellChecking: @[BeatSettingContinuousSpellChecking, @YES],
        BeatSettingIgnoreSpellCheckingInDialogue: @[BeatSettingIgnoreSpellCheckingInDialogue, @NO],
        
		BeatSettingBackupURL: @[BeatSettingBackupURL, @""],
        
		BeatSettingSuppressedAlert: @[BeatSettingSuppressedAlert, @""],
        
        BeatSettingOutlineFontSizeModifier: @[BeatSettingOutlineFontSizeModifier, @0],
        BeatSettingNotepadZoom: @[BeatSettingNotepadZoom, @(1.0)],
        
        BeatSettingShowPageSeparators: @[BeatSettingShowPageSeparators, @NO],
        
        BeatSettingiOSShowWelcomeScreen: @[BeatSettingiOSShowWelcomeScreen, @YES],
        
        BeatSettingPhoneFontSize: @[BeatSettingPhoneFontSize, @(1)],
        
        BeatSettingLineTypeView: @[BeatSettingLineTypeView, @NO],
        
        BeatSettingSectionFontType: @[BeatSettingSectionFontType, @"system"],
        BeatSettingSectionFontSize: @[BeatSettingSectionFontSize, @"18.0"],
        BeatSettingSynopsisFontType: @[BeatSettingSynopsisFontType, @"system"],
        
        BeatSettingAddTitlePageByDefault: @[BeatSettingAddTitlePageByDefault, @NO],
        
        BeatSettingRelativeOutlineHeights: @[BeatSettingRelativeOutlineHeights, @NO],
        
        BeatSettingParagraphPaginationMode: @[BeatSettingParagraphPaginationMode, @0],
        
        BeatSettingHideThumbnailView: @[BeatSettingHideThumbnailView, @NO]
	};
}

- (instancetype)init
{
	self = [super init];
	return self;
}

- (void)readUserDefaultsFor:(id)target
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	for (NSString *docKey in userDefaults.allKeys) {
		NSArray *values = userDefaults[docKey];
		
		NSString *settingKey = values[0];
		id defaultValue = values[1];
		id value;
		
		if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
			// Use default
			value = defaultValue;
		} else {
			value = [NSUserDefaults.standardUserDefaults objectForKey:settingKey];
			
			if ([value isKindOfClass:NSString.class]) {
				// We need to jump through some weird backwards compatibility hoops here.
				// Let's convert "YES" and "NO" string values to bool and save them.
				NSString *str = value;
				
				if ([str isEqualToString:@"YES"] || [str isEqualToString:@"NO"]) {
                    value = ([str isEqualToString:@"YES"]) ? @YES : @NO;
				}
				
				// Use default when the string is empty
				if (str.length == 0) value = defaultValue;
			}
		}
		
		[target setValue:value forKey:docKey];
	}
}

- (id)defaultValueFor:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	if (userDefaults[key] == nil) {
		NSLog(@"WARNING: User default key does not exist: %@", key);
		return nil;
	}

	NSArray *values = userDefaults[key];
	return values[1];
}

- (void)resetToDefault:(NSString*)key {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}

- (NSInteger)getInteger:(NSString*)docKey
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[docKey];
	
	NSString *settingKey = values[0];
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
		return [(NSNumber*)values[1] integerValue];
	} else {
		return [NSUserDefaults.standardUserDefaults integerForKey:settingKey];
	}
}

- (CGFloat)getFloat:(NSString*)docKey
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[docKey];
	
	NSString *settingKey = values[0];
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
		return [(NSNumber*)values[1] floatValue];
	} else {
		return [NSUserDefaults.standardUserDefaults floatForKey:settingKey];
	}
}

- (BOOL)getBool:(NSString*)docKey
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[docKey];
    
    // No default value provided
    if (values.count < 2) {
        NSLog(@"WARNING: No default value specified for key '%@'", docKey);
        return false;
    }
	
	NSString *settingKey = values[0];
	if ([NSUserDefaults.standardUserDefaults objectForKey:settingKey] == nil) {
        // No value set, return default.
		return [(NSNumber*)values[1] boolValue];
	} else {
		return [NSUserDefaults.standardUserDefaults boolForKey:settingKey];
	}
}

- (__nullable id)get:(NSString*)docKey {
	if (docKey == nil || docKey.length == 0) return nil;
	
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[docKey];
    if (values == nil) return nil;
    
	NSString *settingKey = values[0];
    
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
		return values[1];
	} else {
		id setting = [NSUserDefaults.standardUserDefaults objectForKey:settingKey];
		if (setting == nil) return nil;
		
		// Return default value for empty strings
		if ([setting isKindOfClass:NSString.class]) {
			NSString *settingStr = setting;
			if (settingStr.length == 0) return values[1];
			else return settingStr;
		}
		// Otherwise just return the saved value
		return [NSUserDefaults.standardUserDefaults valueForKey:settingKey];
	}
}

- (void)resetSuppressedAlerts
{
    [NSUserDefaults.standardUserDefaults removeObjectForKey:BeatSettingSuppressedAlert];
}

- (BOOL)isSuppressed:(NSString*)key
{
	NSDictionary *suppressions = [NSUserDefaults.standardUserDefaults objectForKey:BeatSettingSuppressedAlert];
	if (![suppressions objectForKey:key]) {
		return NO;
	} else {
		return [(NSNumber*)[suppressions objectForKey:key] boolValue];
	}
}

- (void)setSuppressed:(NSString *)key value:(bool)value
{
	NSMutableDictionary *suppressions = [[NSUserDefaults.standardUserDefaults objectForKey:BeatSettingSuppressedAlert] mutableCopy];
	if (!suppressions) suppressions = NSMutableDictionary.new;
		

	[suppressions setObject:@(value) forKey:key];
	[NSUserDefaults.standardUserDefaults setValue:suppressions forKey:BeatSettingSuppressedAlert];
}

- (void)saveBool:(bool)value forKey:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[key];
	
	if (values) {
		NSString *settingKey = values[0];
		[NSUserDefaults.standardUserDefaults setBool:value forKey:settingKey];
	}
}

/// Toggles a boolean value on/off
- (void)toggleBool:(NSString*)key
{
    bool value = [self getBool:key];
    [self saveBool:!value forKey:key];
}


- (void)saveInteger:(NSInteger)value forKey:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[key];
	
	if (values) {
		NSString *settingKey = values[0];
		[NSUserDefaults.standardUserDefaults setInteger:value forKey:settingKey];
	}
}
- (void)saveFloat:(CGFloat)value forKey:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[key];
	
	if (values) {
		NSString *settingKey = values[0];
		[NSUserDefaults.standardUserDefaults setFloat:value forKey:settingKey];
	}
}
- (void)save:(id)value forKey:(NSString *)key {
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSArray *values = userDefaults[key];
	
	if (values) {
		NSString *settingKey = values[0];
		[NSUserDefaults.standardUserDefaults setValue:value forKey:settingKey];
	}
}

- (void)saveSettingsFrom:(id)target
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	
	for (NSString *docKey in userDefaults.allKeys) {
		id value = [target valueForKey:docKey];
		NSArray *keyValues = userDefaults[docKey];
		
		if (keyValues && value != nil) [NSUserDefaults.standardUserDefaults setValue:value forKey:keyValues[0]];
	}
}

- (void)removeUserDefaults
{
    NSDictionary * dict = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (id key in dict) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

@end
/*
 
 never loved  this hard this fast before
 but then again
 I've never loved a boy like you before
 never had somebody sweep me off the floor
 the way you do
 
 never came this hard, this long before
 but then again
 I've never fucked a boy like you before
 never had somebody I could fuck hardcore
 until I met you
 
 */
