//
//  BeatTagging.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DynamicColor.h"
#import "BeatColors.h"
#import "BeatTextView.h"
#import "ContinuousFountainParser.h"

@class BeatTag;

typedef enum : NSInteger {
	NoTag = 0,
	CharacterTag,
	PropTag,
	CostumeTag,
	MakeupTag,
	VFXTag,
	SpecialEffectTag,
	AnimalTag,
	ExtraTag,
	VehicleTag,
	MusicTag,
	GenericTag
} BeatTagType;

@class BeatTagging;
@protocol BeatTaggingDelegate <NSObject>
@property (readonly, weak) ContinuousFountainParser *parser;
@property (readonly, weak) NSTextView *textView;

- (void)tagRange:(NSRange)range withTag:(BeatTag*)tag;
- (void)tagRange:(NSRange)range withType:(BeatTagType)type;
- (bool)tagExists:(NSString*)string type:(BeatTagType)type;
- (void)tagRange:(NSRange)range withDefinition:(id)definition;
- (NSArray*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type;
- (id)definitionWithName:(NSString*)name type:(BeatTagType)type;

@end


@interface TagSearchResult : NSObject
@property (nonatomic) NSString *string;
@property (nonatomic) CGFloat distance;
- (instancetype)initWith:(NSString*)string distance:(CGFloat)distance;
@end

@interface BeatTagging : NSObject
@property (weak) id<BeatTaggingDelegate> delegate;

+ (NSArray*)tags;
+ (BeatTagType)tagFor:(NSString*)tag;
//+ (NSDictionary*)taggedRangesIn:(NSAttributedString*)string;
+ (NSArray*)styledTags;
+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray*)lines;
+ (NSDictionary*)tagColors;
+ (NSColor*)colorFor:(BeatTagType)tag;
+ (NSString*)keyFor:(BeatTagType)tag;
+ (NSArray*)definitionsForTags:(NSArray*)tags;
+ (NSString*)newId;
+ (NSString*)hexForKey:(NSString*)key;

- (instancetype)initWithDelegate:(id<BeatTaggingDelegate>)delegate;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (void)bakeTags;
- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene;
- (void)setupTextView:(NSTextView*)textView;
- (NSArray*)getDefinitions;
- (void)loadTags:(NSArray*)tags definitions:(NSArray*)definitions;
- (BeatTag*)addTag:(NSString*)name type:(BeatTagType)type;
- (NSArray*)getTags;
- (NSArray*)allTags;
- (bool)tagExists:(NSString*)string type:(BeatTagType)type;
- (NSArray*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type;
- (id)definitionWithName:(NSString*)name type:(BeatTagType)type;

@end
