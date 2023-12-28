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
extern NSString * const BeatSettingPrintSceneNumbers;
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
extern NSString * const BeatSettingZoomLevel;

extern NSString * const BeatSettingContinuousSpellChecking;

extern NSString * const BeatSettingShowSynopsisInOutline;
extern NSString * const BeatSettingShowSceneNumbersInOutline;
extern NSString * const BeatSettingShowNotesInOutline;
extern NSString * const BeatSettingShowMarkersInOutline;
extern NSString * const BeatSettingShowSnapshotsInOutline;

extern NSString * const BeatSettingSuppressedAlert;

extern NSString * const BeatSettingOutlineFontSizeModifier;

extern NSString* const BeatSettingShowPageSeparators;

extern NSString* const BeatSettingFocusMode;

+ (BeatUserDefaults*)sharedDefaults;

+ (NSDictionary*)userDefaults;
- (void)readUserDefaultsFor:(id)target;
- (void)resetToDefault:(NSString*)key;
- (void)save:(id)value forKey:(NSString*)key;
- (BOOL)isSuppressed:(NSString*)key;
- (void)setSuppressed:(NSString*)key value:(bool)value;
- (void)saveBool:(bool)value forKey:(NSString*)key;
- (__nullable id)get:(NSString*)docKey;
- (BOOL)getBool:(NSString*)docKey;
- (CGFloat)getFloat:(NSString*)docKey;
- (void)saveSettingsFrom:(id)target;
- (NSInteger)getInteger:(NSString*)docKey;
- (void)saveInteger:(NSInteger)value forKey:(NSString*)key;
- (void)saveFloat:(CGFloat)value forKey:(NSString*)key;
- (id)defaultValueFor:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
