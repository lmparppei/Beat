//
//  BeatTagging.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define TagColor UIColor
    #define TagFont UIFont
    #define BeatEditorTextView UITextView
    #define BeatTagView UITextView
#else
    #import <Cocoa/Cocoa.h>
    #define TagColor NSColor
    #define TagFont NSFont
    #define BeatTagView NSTextView
#endif

#import <BeatCore/BeatEditorDelegate.h>

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
@class TagDefinition;

@protocol BeatTaggingDelegate <BeatEditorDelegate>
// Do we need some special stuff here?
@end

@interface TagSearchResult : NSObject
@property (nonatomic) NSString *string;
@property (nonatomic) CGFloat distance;
- (instancetype)initWith:(NSString*)string distance:(CGFloat)distance;
@end

@interface BeatTagging : NSObject
@property (weak) IBOutlet id<BeatTaggingDelegate> delegate;
@property (weak) IBOutlet BXTextView* tagTextView;

+ (NSString*)attributeKey;
/// All available tag categories. It's a hard-coded array to retain the order.
+ (NSArray<NSString*>*)categories;
+ (BeatTagType)tagFor:(NSString*)tag;
/// Returns an array of all tag types as localized strings and a colored circle
+ (NSArray<NSAttributedString*>*)styledTags;
/// Returns localized tag type name and a colored circle
+ (NSAttributedString*)styledTagFor:(NSString*)tag;
/// Bake tags to line elements
+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray*)lines;
/// Dictionary of colors associated with tags (string key)
+ (NSDictionary<NSString*, BXColor*>*)tagColors;
/// Returns the color for given tag type
+ (TagColor*)colorFor:(BeatTagType)tag;
/// Returns the key name (string) for given tag type
+ (NSString*)keyFor:(BeatTagType)tag;
/// Returns the definitions for all tags in an array
+ (NSMutableArray<TagDefinition*>*)definitionsForTags:(NSArray<BeatTag*>*)tags;
/// Creates a new UUID and returns it as string
+ (NSString*)newId;
/// ...
+ (NSString*)hexForKey:(NSString*)key;
/// Returns SF Symbol names for given tags
+ (NSDictionary<NSNumber*, NSString*>*)tagIcons;
/// Keys are raw integer values as `NSNumber`, values are their keys.
+ (NSDictionary<NSNumber*,NSString*>*)tagKeys;
/// Returns localized tag name for string key
+ (NSString*)localizedTagNameFor:(NSString*)tag;
/// Returns localized tag name for type
+ (NSString*)localizedTagNameForType:(BeatTagType)type;

- (void)setup;

- (instancetype)initWithDelegate:(id<BeatTaggingDelegate>)delegate;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (NSArray<TagDefinition*>*)tagsWithTypeName:(NSString*)type;
- (void)bakeTags;
- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene;
- (NSArray*)getDefinitions;
- (void)loadTags:(NSArray*)tags definitions:(NSArray*)definitions;
- (BeatTag*)addTag:(NSString*)name type:(BeatTagType)type;
- (NSArray*)getTags;
- (NSArray*)allTags;
- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)sortedTags;
- (bool)tagExists:(NSString*)string type:(BeatTagType)type;
- (NSArray*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type;
- (id)definitionWithName:(NSString*)name type:(BeatTagType)type;
- (NSArray<OutlineScene*>*)scenesForTagDefinition:(TagDefinition*)tag;

- (void)tagRange:(NSRange)range withTag:(BeatTag*)tag;
- (void)tagRange:(NSRange)range withType:(BeatTagType)type;
- (void)tagRange:(NSRange)range withDefinition:(id)definition;
- (void)updateTaggingData;

@end
