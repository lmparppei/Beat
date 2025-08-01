//
//  BeatDocumentSettings.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatDocumentSettingDelegate
- (void)addToChangeCount;
@end

@interface BeatDocumentSettings : NSObject
-(id)initWithDelegate:(_Nullable id<BeatDocumentSettingDelegate>)delegate;

+ (NSDictionary*)defaultValues;
+ (NSDictionary*)defaultValue:(NSString*)key;
- (NSDictionary*)defaultValues;

@property (nonatomic, weak) id<BeatDocumentSettingDelegate> delegate;
@property (atomic) NSMutableDictionary *settings;

extern NSString * const DocSettingRevisions;
extern NSString * const DocSettingHiddenRevisions;
extern NSString * const DocSettingRevisedPageColor;
extern NSString * const DocSettingColorCodePages;
extern NSString * const DocSettingRevisionColor;
extern NSString * const DocSettingRevisionLevel;
extern NSString * const DocSettingRevisionMode;
extern NSString * const DocSettingSceneNumberStart;
extern NSString * const DocSettingTags;
extern NSString * const DocSettingTagDefinitions;
extern NSString * const DocSettingCaretPosition;
extern NSString * const DocSettingPageSize;
extern NSString * const DocSettingActivePlugins;
extern NSString * const DocSettingChangedIndices;
extern NSString * const DocSettingReviews;
extern NSString * const DocSettingHeadingUUIDs;
extern NSString * const DocSettingSidebarVisible;
extern NSString * const DocSettingSidebarWidth;
extern NSString * const DocSettingLocked;
extern NSString * const DocSettingCharacterGenders;
extern NSString * const DocSettingCharacterData;

extern NSString * const DocSettingHeader;
extern NSString * const DocSettingHeaderAlignment;

extern NSString * const DocSettingPrintSceneNumbers;
extern NSString * const DocSettingPrintSynopsis;
extern NSString * const DocSettingPrintSections;
extern NSString * const DocSettingPrintNotes;

extern NSString * const DocSettingStylesheet;

extern NSString * const DocSettingWindowWidth;
extern NSString * const DocSettingWindowHeight;

extern NSString * const DocSettingNovelLineHeightMultiplier;
extern NSString * const DocSettingContentAlignment;

extern NSString * const DocSettingFirstPageNumber;
extern NSString * const DocSettingPageNumberingMode;

extern NSString * const DocSettingTextLengthAtSave;

- (void)setBool:(NSString*)key as:(bool)value;
- (void)toggleBool:(NSString*)key;
- (void)setInt:(NSString*)key as:(NSInteger)value;
- (void)setFloat:(NSString*)key as:(CGFloat)value;
- (void)setString:(NSString*)key as:(NSString*)value;
- (void)set:(NSString*)key as:(id)value;

- (NSInteger)getInt:(NSString*)key;
- (bool)getBool:(NSString*)key;
- (NSString*)getString:(NSString *) key;
- (CGFloat)getFloat:(NSString *)key;
- (id _Nullable)get:(NSString*)key;
- (bool)has:(NSString*)key;

- (void)remove:(NSString *)key;

/// Returns a setting string with only selected keys
- (NSString*)getSettingsStringWithKeys:(NSArray<NSString*>*)keys;
/// Returns a full settings string from current document
- (NSString*)getSettingsString;
- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings;
- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings excluding:(NSArray<NSString*>* _Nullable)excludedKeys;
/// Reads settings from a document file and returns the range of actual content
- (NSRange)readSettingsAndReturnRange:(NSString*)string;

/// Returns an array of ESSENTIAL values. This is used by version control to store crucial information from settings and nothing else.
+ (NSArray<NSString*>*)essentialValues;
@end

NS_ASSUME_NONNULL_END
