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

#pragma mark - Search result items for tagging using Levenshtein algorithm

@interface TagSearchResult : NSObject
@property (nonatomic) NSString *string;
@property (nonatomic) CGFloat distance;
- (instancetype)initWith:(NSString*)string distance:(CGFloat)distance;
@end


#pragma mark - Main tagging class

/**
 
 Minimal tagging implementation. This relies on adding attributes into the BeatEditorView string, and tagging data is NOT present in the screenplay text. It is saved as a separate JSON string inside the document settings.  Parsed `Line` objects will know their tags once you call `bakeTags` method in this class, but other than that, while editing the text tags are only present as attributes in text view.
 
 We have two classes, `BeatTag` and `TagDefinition` (sorry for the inconsistence). `BeatTag`s are added as attributes to the string (attribute name `"BeatTag"`), and they contain a reference to their definition. Definitions are created on the fly and get their text content from the first time something is tagged. You can alter the definition text as you wish. This is very similar to how Final Draft has implemented tagging, which is why converting Beat tags to FDX tags is quite simple, and vice-versa.
 
 # Basic functionality
 
 User tags a range in editor:
    -> editor presents a menu for existing items in the selected category
    -> add a reference to the tag definition as an attribute to the string
 
 Save document:
    -> create an array of tag definitions which are still present in the screenplay
       (some might have been deleted)
    -> save tag ranges as previously, just include the tag definition reference

 Load document:
    -> load tag definitions using this class, create the aforementioned definition array
    -> load ranges and use this class to match tags to definitions
 
 Nice and easy, just needs some work.
 
 */
@interface BeatTagging : NSObject
@property (weak) IBOutlet id<BeatEditorDelegate> delegate;
@property (weak) IBOutlet BXTextView* tagTextView;

#pragma mark - Class methods

+ (NSString*)attributeKey;
+ (NSString*)notificationName;

/// All available tag categories. It's a hard-coded array to retain the order.
+ (NSArray<NSString*>*)categories;
/// Returns enum type for given tag string key
+ (BeatTagType)tagFor:(NSString*)tag;
/// Returns the key name (string) for given tag type
+ (NSString*)keyFor:(BeatTagType)tag;

/// Returns an array of all tag types as localized strings and a colored circle
+ (NSArray<NSAttributedString*>*)styledTagsForMenu;
/// Returns localized tag type name and a colored circle
+ (NSAttributedString*)styledTagFor:(NSString*)tag;
/// Bake tags to line elements
+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray*)lines;
/// Dictionary of colors associated with tags (string key)
+ (NSDictionary<NSString*, BXColor*>*)tagColors;
/// Returns the color for given tag type
+ (TagColor*)colorFor:(BeatTagType)tag;
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
+ (NSString*)localizedTagNameForKey:(NSString*)tag;
/// Returns localized tag name for type
+ (NSString*)localizedTagNameForType:(BeatTagType)type;


#pragma mark - Instance (document-bound) methods

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;

/// Loads tags for current document from document settings and applies tag attributes to editor text.
- (void)setup;
/// Loads given list of tag items with definitions and applies tag attributes to editor text.
- (void)loadTags:(NSArray*)tags definitions:(NSArray*)definitions;

/// Returns a dictionary of tag definitions in current document
- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)tagsForScene:(OutlineScene*)scene;
/// Returns a list of tag definitions in current document with given type name
- (NSArray<TagDefinition*>*)tagsWithTypeName:(NSString*)type;
/// Bakes tags from an attributed string into lines.
- (void)bakeTags;
/// A UI string for listing tags in given scene
- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene;
/// Returns all tag __definitions__ in current document.
- (NSArray*)getDefinitions;
/// Creates a tag item (the ones that are attached as attributes in text view) with given name and type
- (BeatTag*)addTag:(NSString*)name type:(BeatTagType)type;
/// Returns an array for saving the tags for converting to JSON
- (NSArray<NSDictionary<NSString*,id>*>*)serializedTagData;
/// Returns an array of **all** tags in given document
- (NSArray*)allTags;
/// Returns a dictionary of all tag definitions by type
- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)sortedTags;
/// Returns `true` if there is a tag definition for given name and type
- (bool)tagDefinitionExists:(NSString*)string type:(BeatTagType)type;
/// Returns an array of tag definitions that fit both the search string and type. It uses Levenshtein algorithm, so results include things that *somehow* contain the string.
- (NSArray*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type;
/// Returns the tag definition with given name and type.
- (TagDefinition*)definitionWithName:(NSString*)name type:(BeatTagType)type;
/// Returns all scenes which contain the given tag definition.
- (NSArray<OutlineScene*>*)scenesForTagDefinition:(TagDefinition*)tag;

#pragma mark - Tagging methods

/// Tags a range in editor with given tag item
- (void)tagRange:(NSRange)range withTag:(BeatTag*)tag;
/// Tags a range in editor with tag type, taking the tag definition name from selected range.
- (void)tagRange:(NSRange)range withType:(BeatTagType)type;
- (void)tagRange:(NSRange)range withDefinition:(TagDefinition*)definition;
- (void)updateTaggingData;

@end
