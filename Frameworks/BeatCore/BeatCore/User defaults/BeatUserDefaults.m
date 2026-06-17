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

#define DEFAULT_MAGNIFICATION 1.5

NSString* const BeatSettingMatchParentheses				= @"matchParentheses";

NSString* const BeatSettingShowPageNumbers 				= @"showPageNumbers";
NSString* const BeatSettingShowPageSeparators           = @"showPageSeparators";
NSString* const BeatSettingShowSceneNumbers 			= @"showSceneNumberLabels";

NSString* const BeatSettingAutosave 					= @"autosave";
NSString* const BeatSettingTypewriterMode 				= @"typewriterMode";
NSString* const BeatSettingHideFountainMarkup 			= @"hideFountainMarkup";
NSString* const BeatSettingAutocomplete 				= @"autocomplete";
NSString* const BeatSettingFontStyle                    = @"fontStyle";

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
NSString* const BeatSettingForcedAppearance             = @"Forced Appearance";
NSString* const BeatSettingLineTypeView                 = @"lineTypeView";

NSString* const BeatSettingSectionFontType              = @"sectionFontType";
NSString* const BeatSettingSectionFontSize              = @"sectionFontSize";
NSString* const BeatSettingSynopsisFontType             = @"synopsisFontType";

NSString* const BeatSettingAddTitlePageByDefault        = @"addTitlePageByDefault";

NSString* const BeatSettingRelativeOutlineHeights       = @"relativeOutlineHeights";

NSString* const BeatSettingParagraphPaginationMode      = @"paragraphPaginationMode";

NSString* const BeatSettingHideThumbnailView            = @"hideThumbnailView";
NSString* const BeatSettingInputAssistantHidden         = @"hideInputAssistant";

NSString* const BeatSpellCheckingLanguage               = @"spellCheckingLanguage";

NSString* const BeatSettingAllowAllFileTypes            = @"allowAllFileTypes";

NSString* const BeatSettingSmartQuotes                  = @"smartQuotes";


+ (BeatUserDefaults*)sharedDefaults
{
	static BeatUserDefaults* sharedDefaults;
	if (!sharedDefaults) {
		sharedDefaults = [[BeatUserDefaults alloc] init];
        [sharedDefaults convertLegacySettings];
	}
	return sharedDefaults;
}

+ (NSDictionary*)userDefaults
{
    static NSDictionary* userDefaults;
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // For the barbaric countries still using imperial units and non-standard paper sizes,
        // we'll set default-default paper size to US Letter (1)
        NSInteger pageSize = 0;
        NSString *language = NSLocale.currentLocale.localeIdentifier;
        if ([language isEqualToString:@"en_US"]) pageSize = 1;
        
        userDefaults = @{
            // Structure: Document class property name, key, default
            BeatSettingMatchParentheses: @YES,
            BeatSettingShowPageNumbers: @YES,
            BeatSettingAutomaticLineBreaks: @YES,
            BeatSettingShowSceneNumbers: @YES,
            BeatSettingHideFountainMarkup: @NO,
            BeatSettingTypewriterMode: @NO,
            BeatSettingAutosave: @NO,
            BeatSettingAutocomplete: @YES,
            //BeatSettingUseSansSerif: @[FONT_STYLE_KEY, @NO],
            BeatSettingFontStyle: @0,
            
            BeatSettingDarkMode: @NO,
            BeatSettingForcedAppearance: @0,

            BeatSettingMagnification: @(DEFAULT_MAGNIFICATION),
            BeatSettingUpdatePluginsAutomatically: @YES,
            
            BeatSettingHeadingStyleBold: @YES,
            BeatSettingHeadingStyleUnderlined: @NO,
            BeatSettingShotStyleBold: @YES,
            BeatSettingShotStyleUnderlined: @NO,
        
            BeatSettingDefaultPageSize: @(pageSize),
            BeatSettingDisableFormatting: @NO,
            BeatSettingShowMarkersInScrollbar: @NO,
            BeatSettingSceneHeadingSpacing: @2,
            BeatSettingNovelLineSpacing: @(2.0),
            BeatSettingScreenplayItemMore: @"MORE",
            BeatSettingScreenplayItemContd: @"CONT'D",
            BeatSettingShowRevisions: @YES,
            BeatSettingShowRevisedTextColor: @NO,
            BeatSettingShowTags: @YES,
            BeatSettingAutomaticContd: @YES,
            
            BeatSettingFocusMode: @(0),
            
            BeatSettingShowHeadingsInOutline: @YES,
            BeatSettingShowSynopsisInOutline: @YES,
            BeatSettingShowSceneNumbersInOutline: @YES,
            BeatSettingShowNotesInOutline: @YES,
            BeatSettingShowMarkersInOutline: @YES,
            BeatSettingShowSnapshotsInOutline: @YES,
            
            BeatSettingContinuousSpellChecking: @YES,
            BeatSettingIgnoreSpellCheckingInDialogue: @NO,
            BeatSettingSmartQuotes: @([NSUserDefaults.standardUserDefaults boolForKey:@"NSAutomaticQuoteSubstitutionEnabled"]),
            
            BeatSettingBackupURL: @"",
            
            BeatSettingSuppressedAlert: @"",
            
            BeatSettingOutlineFontSizeModifier: @0,
            BeatSettingNotepadZoom: @(1.0),
            
            BeatSettingShowPageSeparators: @NO,
            
            BeatSettingiOSShowWelcomeScreen: @YES,
            
            BeatSettingPhoneFontSize: @(1),
            
            BeatSettingLineTypeView: @NO,
            
            BeatSettingSectionFontType: @"system",
            BeatSettingSectionFontSize: @"18.0",
            BeatSettingSynopsisFontType: @"system",
            
            BeatSettingAddTitlePageByDefault: @NO,
            
            BeatSettingRelativeOutlineHeights: @NO,
            
            BeatSettingParagraphPaginationMode: @0,
            
            BeatSettingHideThumbnailView: @NO,
            
            BeatSpellCheckingLanguage: @""
        };
    });
    
    return userDefaults;
}

- (instancetype)init
{
	self = [super init];
	return self;
}

- (void)readUserDefaultsFor:(id)target
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	for (NSString *localKey in userDefaults.allKeys) {
        NSString* settingKey = [self settingKeyFor:localKey];
        id defaultValue = userDefaults[localKey];
        
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
		
		[target setValue:value forKey:localKey];
	}
}

- (id)defaultValueFor:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	if (userDefaults[key] == nil) {
		NSLog(@"WARNING: User default key does not exist: %@", key);
		return nil;
	}

	return userDefaults[key];
}

- (void)resetToDefault:(NSString*)key
{
    NSString* settingKey = [self settingKeyFor:key];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:settingKey];
}


#pragma mark - Getters

- (NSInteger)getInteger:(NSString*)key
{
	NSNumber* defaultValue = BeatUserDefaults.userDefaults[key];
    
    NSString *settingKey = [self settingKeyFor:key];
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
		return defaultValue.integerValue;
	} else {
		return [NSUserDefaults.standardUserDefaults integerForKey:settingKey];
	}
}

- (CGFloat)getFloat:(NSString*)key
{
	NSNumber* defaultValue = BeatUserDefaults.userDefaults[key];
	
    NSString *settingKey = [self settingKeyFor:key];
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
		return defaultValue.floatValue;
	} else {
		return [NSUserDefaults.standardUserDefaults floatForKey:settingKey];
	}
}

- (BOOL)getBool:(NSString*)key
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	NSNumber *defaultValue = userDefaults[key];
    	
    NSString *settingKey = [self settingKeyFor:key];
	if ([NSUserDefaults.standardUserDefaults objectForKey:settingKey] == nil) {
        // No value set, return default.
        return defaultValue.boolValue;
	} else {
		return [NSUserDefaults.standardUserDefaults boolForKey:settingKey];
	}
}

- (__nullable id)get:(NSString*)key
{
	if (key == nil || key.length == 0) return nil;
	
	id defaultValue = BeatUserDefaults.userDefaults[key];
    
    NSString *settingKey = [self settingKeyFor:key];
    
	if (![NSUserDefaults.standardUserDefaults objectForKey:settingKey]) {
        return defaultValue;
	} else {
		id setting = [NSUserDefaults.standardUserDefaults objectForKey:settingKey];
		if (setting == nil) return nil;
		
		// Return default value for empty strings
		if ([setting isKindOfClass:NSString.class]) {
			NSString *settingStr = setting;
            return (settingStr.length == 0) ? defaultValue : settingStr;
		}
		// Otherwise just return the saved value
		return [NSUserDefaults.standardUserDefaults valueForKey:settingKey];
	}
}

- (void)resetSuppressedAlerts
{
    NSString* settingKey = [self settingKeyFor:BeatSettingSuppressedAlert];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:settingKey];
}

- (BOOL)isSuppressed:(NSString*)key
{
    NSString* settingKey = [self settingKeyFor:BeatSettingSuppressedAlert];
	NSDictionary *suppressions = [NSUserDefaults.standardUserDefaults objectForKey:settingKey];
	if (![suppressions objectForKey:key]) {
		return NO;
	} else {
		return [(NSNumber*)[suppressions objectForKey:key] boolValue];
	}
}

- (void)setSuppressed:(NSString *)key value:(bool)value
{
    NSString* settingKey = [self settingKeyFor:BeatSettingSuppressedAlert];
	NSMutableDictionary *suppressions = [[NSUserDefaults.standardUserDefaults objectForKey:settingKey] mutableCopy];
	if (!suppressions) suppressions = NSMutableDictionary.new;
		
	[suppressions setObject:@(value) forKey:key];
	[NSUserDefaults.standardUserDefaults setValue:suppressions forKey:settingKey];
}

- (void)saveBool:(bool)value forKey:(NSString*)key
{
    NSString *settingKey = [self settingKeyFor:key];
    [NSUserDefaults.standardUserDefaults setBool:value forKey:settingKey];
}

/// Toggles a boolean value on/off
- (void)toggleBool:(NSString*)key
{
    bool value = [self getBool:key];
    [self saveBool:!value forKey:key];
}

- (void)saveInteger:(NSInteger)value forKey:(NSString*)key
{
    NSString *settingKey = [self settingKeyFor:key];
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:settingKey];
}
- (void)saveFloat:(CGFloat)value forKey:(NSString*)key
{
    NSString *settingKey = [self settingKeyFor:key];
    [NSUserDefaults.standardUserDefaults setFloat:value forKey:settingKey];
}

- (void)save:(id)value forKey:(NSString *)key
{
    NSString *settingKey = [self settingKeyFor:key];
    [NSUserDefaults.standardUserDefaults setValue:value forKey:settingKey];
}

/// Due to some legacy compatibility, we need to do a little trickery and find the *actual* setting key.
- (NSString*)settingKeyFor:(NSString*)key
{
    NSMutableString* settingKey = [NSMutableString stringWithString:key];
    
    // Prefix our setting
    [settingKey insertString:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@"."] atIndex:0];
    
    return settingKey;
}

- (void)saveSettingsFrom:(id)target
{
	NSDictionary* userDefaults = BeatUserDefaults.userDefaults;
	
	for (NSString *key in userDefaults.allKeys) {
		id value = [target valueForKey:key];
        NSString* settingKey = [self settingKeyFor:key];
        
		if (value != nil) [NSUserDefaults.standardUserDefaults setValue:value forKey:settingKey];
	}
}

- (void)removeUserDefaults
{
    /*
    NSDictionary * dict = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (id key in dict) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
     */
    
    [NSUserDefaults.standardUserDefaults removeObjectForKey:BeatSettingSectionFontType];
}

/// Back in the day, I was an idiot and didn't correctly prefix my settings. Called when the singleton is initialized.
- (void)convertLegacySettings
{
    for (NSString* key in BeatUserDefaults.userDefaults.allKeys) {
        id value = [NSUserDefaults.standardUserDefaults valueForKey:key];
        if (value != nil) {
            NSString* newKey = [self settingKeyFor:key];

            [NSUserDefaults.standardUserDefaults setValue:value forKey:newKey];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
        }
    }
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
