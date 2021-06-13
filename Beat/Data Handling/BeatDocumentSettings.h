//
//  BeatDocumentSettings.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatEditorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentSettings : NSObject
@property (nonatomic) NSMutableDictionary *settings;
@property (weak) id<BeatEditorDelegate> delegate;

extern NSString * const DocSettingRevisions;
extern NSString * const DocSettingRevisionColor;
extern NSString * const DocSettingSceneNumberStart;
extern NSString * const DocSettingTags;
extern NSString * const DocSettingTagDefinitions;

- (void)setBool:(NSString*)key as:(bool)value;
- (void)setInt:(NSString*)key as:(NSInteger)value;
- (void)setString:(NSString*)key as:(NSString*)value;
- (void)set:(NSString*)key as:(id)value;

- (NSInteger)getInt:(NSString*)key;
- (bool)getBool:(NSString*)key;
- (NSString*)getString:(NSString *) key;
- (id)get:(NSString*)key;

- (void)remove:(NSString *)key;

- (NSString*)getSettingsString;
- (NSRange)readSettingsAndReturnRange:(NSString*)string;
@end

NS_ASSUME_NONNULL_END
