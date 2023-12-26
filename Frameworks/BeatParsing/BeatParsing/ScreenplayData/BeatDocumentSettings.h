//
//  BeatDocumentSettings.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatEditorDelegate;
@interface BeatDocumentSettings : NSObject
@property (atomic) NSMutableDictionary *settings;
@property (weak) id<BeatEditorDelegate> delegate;

extern NSString * const DocSettingRevisions;
extern NSString * const DocSettingHiddenRevisions;
extern NSString * const DocSettingRevisedPageColor;
extern NSString * const DocSettingColorCodePages;
extern NSString * const DocSettingRevisionColor;
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

extern NSString * const DocSettingPrintSynopsis;
extern NSString * const DocSettingPrintSections;
extern NSString * const DocSettingPrintNotes;

extern NSString * const DocSettingStylesheet;

extern NSString * const DocSettingWindowWidth;
extern NSString * const DocSettingWindowHeight;

- (void)setBool:(NSString*)key as:(bool)value;
- (void)setInt:(NSString*)key as:(NSInteger)value;
- (void)setFloat:(NSString*)key as:(NSInteger)value;
- (void)setString:(NSString*)key as:(NSString*)value;
- (void)set:(NSString*)key as:(id)value;

- (NSInteger)getInt:(NSString*)key;
- (bool)getBool:(NSString*)key;
- (NSString*)getString:(NSString *) key;
- (NSInteger)getFloat:(NSString *)key;
- (id)get:(NSString*)key;
- (bool)has:(NSString*)key;

- (void)remove:(NSString *)key;

- (NSString*)getSettingsString;
- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary*)additionalSettings;
- (NSRange)readSettingsAndReturnRange:(NSString*)string;
@end

NS_ASSUME_NONNULL_END
