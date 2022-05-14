//
//  BeatTagging.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define TagColor UIColor
    #define TagFont UIFont
    #define BeatEditorView UITextView
    #define BeatTagView UITextView
#else
    #import <Cocoa/Cocoa.h>
    #define TagColor NSColor
    #define TagFont NSFont
    #define BeatTagView NSTextView
#endif

#import "DynamicColor.h"
#import "BeatColors.h"
#import "BeatTextView.h"
#import "ContinuousFountainParser.h"

@class BeatTag;

typedef NS_ENUM(NSInteger, BeatTagType) {
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
};

@class BeatTagging;
@protocol BeatTaggingDelegate <NSObject>
@property (readonly, weak) ContinuousFountainParser *parser;
#if !TARGET_OS_IOS
@property (readonly, weak) BeatTagView *textView;
#else
@property (readonly, weak) UITextView *textView;
#endif

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
@property (weak) IBOutlet id<BeatTaggingDelegate> delegate;
#if !TARGET_OS_IOS
@property (weak) IBOutlet BeatTagView* textView;
#endif

+ (NSArray*)tags;
+ (BeatTagType)tagFor:(NSString*)tag;
//+ (NSDictionary*)taggedRangesIn:(NSAttributedString*)string;
+ (NSArray*)styledTags;
+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray*)lines;
+ (NSDictionary*)tagColors;
+ (TagColor*)colorFor:(BeatTagType)tag;
+ (NSString*)keyFor:(BeatTagType)tag;
+ (NSArray*)definitionsForTags:(NSArray*)tags;
+ (NSString*)newId;
+ (NSString*)hexForKey:(NSString*)key;

- (instancetype)initWithDelegate:(id<BeatTaggingDelegate>)delegate;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (void)bakeTags;
- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene;
- (NSArray*)getDefinitions;
- (void)loadTags:(NSArray*)tags definitions:(NSArray*)definitions;
- (BeatTag*)addTag:(NSString*)name type:(BeatTagType)type;
- (NSArray*)getTags;
- (NSArray*)allTags;
- (bool)tagExists:(NSString*)string type:(BeatTagType)type;
- (NSArray*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type;
- (id)definitionWithName:(NSString*)name type:(BeatTagType)type;

@end
