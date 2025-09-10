//
//  BeatUserDefaults.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatUserDefaults : NSObject

extern NSString * const BeatSettingMatchParentheses;
extern NSString * const BeatSettingShowPageNumbers;
extern NSString * const BeatSettingShowSceneNumbers;

extern NSString * const BeatSettingAutosave;
extern NSString * const BeatSettingTypewriterMode;
extern NSString * const BeatSettingHideFountainMarkup;
extern NSString * const BeatSettingAutocomplete;
extern NSString * const BeatSettingUseSansSerif;
extern NSString * const BeatSettingMagnification;
extern NSString * const BeatSettingAutomaticLineBreaks;
extern NSString * const BeatSettingUpdatePluginsAutomatically;
extern NSString * const BeatSettingBackupURL;

extern NSString * const BeatSettingHeadingStyleBold;
extern NSString * const BeatSettingHeadingStyleUnderlined;
extern NSString * const BeatSettingShotStyleBold;
extern NSString * const BeatSettingShotStyleUnderlined;
extern NSString * const BeatSettingDefaultPageSize;
extern NSString * const BeatSettingDisableFormatting;
extern NSString * const BeatSettingShowMarkersInScrollbar;
extern NSString * const BeatSettingSceneHeadingSpacing;
extern NSString * const BeatSettingScreenplayItemMore;
extern NSString * const BeatSettingScreenplayItemContd;
extern NSString * const BeatSettingShowRevisions;
extern NSString * const BeatSettingShowRevisedTextColor;
extern NSString * const BeatSettingShowTags;
extern NSString * const BeatSettingAutomaticContd;

extern NSString * const BeatSettingNovelLineSpacing;

extern NSString * const BeatSettingContinuousSpellChecking;
extern NSString * const BeatSettingIgnoreSpellCheckingInDialogue;

extern NSString * const BeatSettingShowHeadingsInOutline;
extern NSString * const BeatSettingShowSynopsisInOutline;
extern NSString * const BeatSettingShowSceneNumbersInOutline;
extern NSString * const BeatSettingShowNotesInOutline;
extern NSString * const BeatSettingShowMarkersInOutline;
extern NSString * const BeatSettingShowSnapshotsInOutline;

extern NSString * const BeatSettingSuppressedAlert;

extern NSString * const BeatSettingOutlineFontSizeModifier;
extern NSString * const BeatSettingNotepadZoom;

extern NSString* const BeatSettingShowPageSeparators;

extern NSString* const BeatSettingFocusMode;

extern NSString* const BeatSettingiOSShowWelcomeScreen;
extern NSString* const BeatSettingPhoneFontSize;

extern NSString* const BeatSettingDarkMode;
extern NSString* const BeatSettingLineTypeView;

extern NSString* const BeatSettingSectionFontType;
extern NSString* const BeatSettingSectionFontSize;
extern NSString* const BeatSettingSynopsisFontType;

extern NSString* const BeatSettingAddTitlePageByDefault;

extern NSString* const BeatSettingRelativeOutlineHeights;

extern NSString* const BeatSettingParagraphPaginationMode;

extern NSString* const BeatSettingHideThumbnailView;

/// Returns the user default singleton
+ (BeatUserDefaults*)sharedDefaults;

/// Returns user default dictionary with property names and default values
+ (NSDictionary*)userDefaults;
/// Tries to set all user defaults for given target
- (void)readUserDefaultsFor:(id)target;
/// Resets this setting to default
- (void)resetToDefault:(NSString*)key;
/// Returns the __default__ value for key
- (id)defaultValueFor:(NSString*)key;
/// Removes ALL stored keys
- (void)removeUserDefaults;

/// Resets all suppressed alerts
- (void)resetSuppressedAlerts;
/// Checks if given alert type is suppressed
- (BOOL)isSuppressed:(NSString*)key;
/// Save suppression state for given alert
- (void)setSuppressed:(NSString*)key value:(bool)value;

/// Get ANY value (you have to handle typecasting yourself)
- (__nullable id)get:(NSString*)docKey;
/// Returns a boolean setting value
- (BOOL)getBool:(NSString*)docKey;
/// Returns a float setting value
- (CGFloat)getFloat:(NSString*)docKey;
/// Returns an integer setting value
- (NSInteger)getInteger:(NSString*)docKey;

/// Saves ANY value for the given key. Make sure you are storing correct types.
- (void)save:(id)value forKey:(NSString*)key;
/// Saves a bool value
- (void)saveBool:(bool)value forKey:(NSString*)key;
/// Toggles a boolean value on/off
- (void)toggleBool:(NSString*)key;
/// Saves an integer value
- (void)saveInteger:(NSInteger)value forKey:(NSString*)key;
/// Saves a float value
- (void)saveFloat:(CGFloat)value forKey:(NSString*)key;

/// Saves settings using given object. Checks setting names and tries to access those keys in the target.
- (void)saveSettingsFrom:(id)target;

@end

NS_ASSUME_NONNULL_END
