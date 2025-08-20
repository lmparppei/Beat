//
//  BeatTagging.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/BeatCore.h>
#import "BeatTagging.h"
#import "BeatTagItem.h"
#import "BeatTag.h"
#import "NSString+Levenshtein.h"
#import "BeatColors.h"

#define BXTagOrder @[ @"cast", @"prop", @"vfx", @"sfx", @"animal", @"extras", @"vehicle", @"costume", @"makeup", @"music", @"stunt" ]

#define UIFontSize 11.0

@implementation TagSearchResult
- (instancetype)initWith:(NSString*)string distance:(CGFloat)distance {
	self = [super init];
	self.distance = distance;
	self.string = string;
	return self;
}
@end

@interface BeatTagging ()
@property (nonatomic) NSMutableArray<TagDefinition*> *tagDefinitions;
@property (nonatomic) OutlineScene *lastScene;
@end

@implementation BeatTagging

+ (void)initialize {
	[super initialize];
	[BeatAttributes registerAttribute:BeatTagging.attributeKey];
}

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate {
	self = [super init];
	if (self) {
		self.delegate = delegate;
	}
	
	return self;
}

-(void)awakeFromNib {
    [super awakeFromNib];

}

/// Load tags from document settings
- (void)setup {
	[self loadTags:[_delegate.documentSettings get:DocSettingTags] definitions:[_delegate.documentSettings get:DocSettingTagDefinitions]];
}

+ (NSString*)attributeKey { return @"BeatTag"; }
+ (NSString*)notificationName { return @"BeatTagModified"; } 

+ (NSDictionary<NSNumber*,NSString*>*)tagKeys
{
    static NSDictionary* tagKeys;
    if (tagKeys == nil) tagKeys = @{
        @(CharacterTag): @"cast",
        @(PropTag): @"prop",
        @(VFXTag): @"vfx",
        @(SpecialEffectTag): @"sfx",
        @(AnimalTag): @"animal",
        @(ExtraTag): @"extras",
        @(VehicleTag): @"vehicle",
        @(CostumeTag): @"costume",
        @(MakeupTag): @"makeup",
        @(MusicTag): @"music",
        @(StuntTag): @"stunt"
    };
    
    return tagKeys;
}

+ (NSDictionary<NSNumber*, NSString*>*)tagIcons
{
    static NSDictionary* tagIcons;
    if (tagIcons == nil) tagIcons = @{
        @(CharacterTag): @"person.fill",
        @(PropTag): @"gym.bag.fill",
        @(VFXTag): @"fx",
        @(SpecialEffectTag): @"flame",
        @(AnimalTag): @"dog.fill",
        @(ExtraTag): @"person.3",
        @(VehicleTag): @"bicycle",
        @(CostumeTag): @"tshirt.fill",
        @(MakeupTag): @"theatermask.and.paintbrush.fill",
        @(MusicTag): @"music.note",
        @(StuntTag): @"figure.fall"
    };
    return tagIcons;
}

+ (NSString*)fdxCategoryToBeat:(NSString*)category
{
    NSDictionary* categories = @{
        @"Synopsis": @"other",
        @"Cast": @"cast",
        @"Extras": @"extras",
        @"Stunt": @"stunt",
        @"Stunts": @"stunt",
        @"Vehicle": @"vehicle",
        @"Vehicles": @"vehicle",
        @"Prop": @"prop",
        @"Props": @"prop",
        @"Camera": @"camera",
        @"Special Effect": @"sfx",
        @"Special Effects": @"sfx",
        @"Costume": @"costume",
        @"Makeup": @"makeup",
        @"Makeup & hair": @"makeup",
        @"Animal": @"animal",
        @"Animals": @"animal",
        @"Music": @"music",
        @"Sound": @"sound",
        @"Art": @"other",
        @"Scenography": @"setDesign",
        @"Special Equipment": @"other",
        @"Security": @"other",
        @"Additional Work": @"other",
        @"VFX": @"vfx",
        @"Practical FX": @"sfx",
        @"Other": @"other",
        @"Notes": @"other",
        @"Script Day": @"other",
        @"Unit": @"other",
        @"Location": @"setDesign",
        @"Greenery": @"setDesign"
    };
    
    return categories[category];

}

/// All available tag categories as string
+ (NSArray<NSString*>*)categories
{
    static NSArray* categories;
    if (categories == nil) categories = BXTagOrder;
    return categories;
}

/// Styled tag items for text view tagging menu
+ (NSArray<NSAttributedString*>*)styledTagsForMenu
{
	NSArray *tags = BeatTagging.categories;
    NSMutableArray *styledTags = NSMutableArray.new;
	
	// Add menu item to remove current tag
    NSString* none = [NSString stringWithFormat:@"× %@", [BeatLocalization localizedStringForKey:@"tag.none"]];
	[styledTags addObject:[[NSAttributedString alloc] initWithString:none]];
	
	for (NSString *tag in tags) {
		[styledTags addObject:[self styledTagFor:tag]];
	}
	
	return styledTags;
}


+ (NSString*)localizedTagNameForType:(BeatTagType)type
{
    NSString* tag = [BeatTagging keyFor:type];
    return [BeatTagging localizedTagNameForKey:tag];
}

+ (NSString*)localizedTagNameForKey:(NSString*)tag
{
    return [BeatLocalization localizedStringForKey:[NSString stringWithFormat:@"tag.%@", tag]];
}

+ (NSAttributedString*)styledTagFor:(NSString*)tag
{
	TagColor *color = [(NSDictionary*)[BeatTagging tagColors] valueForKey:tag];
	
    NSString* localizedTag = [BeatLocalization localizedStringForKey:[NSString stringWithFormat:@"tag.%@", tag]];
    
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"● %@", localizedTag]];
	if (color != nil) [string addAttribute:NSForegroundColorAttributeName value:color range:(NSRange){0, 1}];
	return string;
}

+ (NSAttributedString*)styledListTagFor:(NSString*)tag color:(TagColor*)textColor {
	TagColor *color = [(NSDictionary*)[BeatTagging tagColors] valueForKey:tag];
	
	NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
	paragraph.paragraphSpacing = 3.0;
	
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"● %@\n", tag]];
	if (color != nil) [string addAttribute:NSForegroundColorAttributeName value:color range:(NSRange){0, 1}];
	[string addAttribute:NSForegroundColorAttributeName value:textColor range:(NSRange){1, string.length - 1}];
	[string addAttribute:NSFontAttributeName value:[TagFont boldSystemFontOfSize:UIFontSize] range:(NSRange){0, string.length}];
	[string addAttribute:NSParagraphStyleAttributeName value:paragraph range:(NSRange){0, string.length}];
	[string addAttribute:@"TagTitle" value:@"Yes" range:(NSRange){0, string.length - 1}];
	return string;
}

+ (NSDictionary*)tagColors
{
	return @{
		@"cast": [BeatColors color:@"cyan"],
		@"prop": [BeatColors color:@"orange"],
		@"costume": [BeatColors color:@"pink"],
		@"makeup": [BeatColors color:@"green"],
		@"vfx": [BeatColors color:@"purple"],
		@"animal": [BeatColors color:@"yellow"],
		@"extras": [BeatColors color:@"magenta"],
		@"vehicle": [BeatColors color:@"teal"],
		@"sfx": [BeatColors color:@"brown"],
        @"stunt": [BeatColors color:@"blue"],
        @"setDesign": [BeatColors color:@"goldenrod"],
		@"generic": [BeatColors color:@"gray"]
	};
}


+ (BeatTagType)tagFor:(NSString*)tag
{
	// Make the tag lowercase for absolute compatibility
	tag = tag.lowercaseString;
	if ([tag isEqualToString:@"cast"]) return CharacterTag;
	else if ([tag isEqualToString:@"prop"]) return PropTag;
	else if ([tag isEqualToString:@"vfx"]) return VFXTag;
	else if ([tag isEqualToString:@"sfx"]) return SpecialEffectTag;
	else if ([tag isEqualToString:@"animal"]) return AnimalTag;
	else if ([tag isEqualToString:@"extras"]) return ExtraTag;
	else if ([tag isEqualToString:@"vehicle"]) return VehicleTag;
	else if ([tag isEqualToString:@"costume"]) return CostumeTag;
	else if ([tag isEqualToString:@"makeup"]) return MakeupTag;
	else if ([tag isEqualToString:@"music"]) return MusicTag;
    else if ([tag isEqualToString:@"setDesign"]) return SetDesignTag;
    else if ([tag isEqualToString:@"stunt"]) return StuntTag;
	else if ([tag isEqualToString:@"none"]) return NoTag;
	else { return GenericTag; }
}

+ (NSString*)keyFor:(BeatTagType)tag
{
    NSString* key = BeatTagging.tagKeys[@(tag)];
    return (key != nil) ? key : @"generic";
}

+ (TagColor*)colorFor:(BeatTagType)tag {
	NSDictionary *colors = [self tagColors];
	TagColor *color = [colors valueForKey:[self keyFor:tag]];
	if (!color) color = colors[@"generic"];
	
	return color;
}

+ (NSString*)hexForKey:(NSString*)key
{
    TagColor *color = [self tagColors][key.lowercaseString];
	return [BeatColors get16bitHex:color];
}

+ (NSDictionary*)tagDictionary {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *tags = BeatTagging.categories;
	
	for (NSString* tag in tags) {
		[dict setValue:[NSMutableArray array] forKey:tag];
	}

	return dict;
}
+ (NSMutableDictionary*)tagDictionaryWithDictionaries {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *tags = BeatTagging.categories;
	
	for (NSString* tag in tags) {
		[dict setValue:[NSMutableDictionary dictionary] forKey:tag];
	}

	return dict;
}

- (void)loadTags:(NSArray<NSDictionary*>*)tags definitions:(NSArray<NSDictionary*>*)definitions
{
	self.tagDefinitions = NSMutableArray.new;
	for (NSDictionary *dict in definitions) {
		TagDefinition *def = [[TagDefinition alloc] initWithName:dict[@"name"] type:[BeatTagging tagFor:dict[@"type"]] identifier:dict[@"id"]];
		[_tagDefinitions addObject:def];
	}
	
	for (NSDictionary* tag in tags) {
		NSArray *rangeValues = tag[@"range"];
		if (rangeValues.count < 2) continue; // Ignore faulty values
		
		NSInteger loc = [(NSNumber*)rangeValues[0] integerValue];
		NSInteger len = [(NSNumber*)rangeValues[1] integerValue];
		
		NSRange range = (NSRange){ loc, len };
		
		TagDefinition *def = [self definitionForId:tag[@"definition"]];
		BeatTag *newTag = [BeatTag withDefinition:def];
		
		if (range.length > 0) {
			[self tagRange:range withTag:newTag];
		}
	}
}

/**
 This bakes the tag items in text view string into given set of lines. The lines then retain the references to the tag items, which we carry on to FDX export. It's a class method for some reason.
 */
+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray<Line*>*)lines
{
	for (Line *line in lines) {
		if (line.length == 0) continue;
		
        line.tags = NSMutableArray.new;

		// Local string from the attributed content using line range
		if (line.range.location >= textViewString.length) break;
		NSAttributedString *string = [textViewString attributedSubstringFromRange:line.textRange];
		
		// Enumerate through tags in the attributed string		
		[string enumerateAttribute:BeatTagging.attributeKey inRange:(NSRange){0, line.string.length} options:0 usingBlock:^(id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			BeatTag *tag = (BeatTag*)value;
			
			if (!tag || range.length == 0) return;
						
			[line.tags addObject:@{
				@"tag": tag,
				@"range": [NSValue valueWithRange:range]
			}];
		}];
	}
}

- (NSArray<BeatTag*>*)allTags
{
    return [BeatTagging allTagsFrom:_delegate.attributedString];
}

+ (NSArray<BeatTag*>*)allTagsFrom:(NSAttributedString*)string
{
    NSMutableArray<BeatTag*> * tags = NSMutableArray.new;
    [string enumerateAttribute:BeatTagging.attributeKey inRange:(NSRange){0, string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatTag *tag = (BeatTag*)value;
        if (tag.type == NoTag) return; // Just in case
        
        // Save current range of the tag into the object and add to array
        tag.range = range;
        [tags addObject:tag];
    }];
    
    return tags;
}

- (NSArray<TagDefinition*>*)tagsWithTypeName:(NSString*)type
{
    NSMutableArray<TagDefinition*>* tags = NSMutableArray.new;
    NSAttributedString *string = _delegate.attributedString;
    
    [string enumerateAttribute:BeatTagging.attributeKey inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatTag *tag = (BeatTag*)value;
        
        if (![tag.key isEqualToString:type] || tag.definition == nil) return;
        if (![tags containsObject:tag.definition]) [tags addObject:tag.definition];
    }];
    
    return tags;
}

- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)sortedTags
{
    return [self sortedTagsInRange:NSMakeRange(0, self.delegate.text.length)];
}

- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)sortedTagsInRange:(NSRange)searchRange
{
    NSArray* lines = [self.delegate.parser linesInRange:searchRange];
    
	NSDictionary *tags = [BeatTagging tagDictionary];
    NSAttributedString *string = _delegate.attributedString;
	
	[string enumerateAttribute:BeatTagging.attributeKey inRange:searchRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatTag *tag = (BeatTag*)value;
		
		if (tag.type == NoTag) return;
		tag.range = range;
		
		// Add definition to array if it's not present yet
		if (tag.definition) {
			NSMutableArray *tagDefinitions = tags[tag.key];
			if (![tagDefinitions containsObject:tag.definition]) [tagDefinitions addObject:tag.definition];
		}
	}];
    
    for (Line* line in lines) {
        if (!line.isAnyCharacter) continue;
        
        NSString* characterName = line.characterName.uppercaseString;
        BeatTag* tag = [self addTag:characterName type:CharacterTag];
        if (![tags[@"cast"] containsObject:tag.definition]) [tags[@"cast"] addObject:tag.definition];
    }
    
	return tags;
}

- (NSArray<TagDefinition*>*)tagsInRange:(NSRange)searchRange {
    NSArray* lines = [self.delegate.parser linesInRange:searchRange];
    
    NSMutableArray<TagDefinition*>* tags = NSMutableArray.new;
    NSAttributedString *string = _delegate.attributedString;
    
    [string enumerateAttribute:BeatTagging.attributeKey inRange:searchRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatTag *tag = (BeatTag*)value;
        
        if (tag.type == NoTag) return;
        tag.range = range;
        
        // Add definition to array if it's not present yet
        if (tag.definition) {
            if (![tags containsObject:tag.definition]) [tags addObject:tag.definition];
        }
    }];
    
    for (Line* line in lines) {
        if (!line.isAnyCharacter) continue;
        
        NSString* characterName = line.characterName.uppercaseString;
        BeatTag* tag = [self addTag:characterName type:CharacterTag];
        if (![tags containsObject:tag.definition]) [tags addObject:tag.definition];
    }
    
    return tags;
}

- (NSDictionary<NSString*, NSArray<TagDefinition*>*>*)tagsForScene:(OutlineScene*)scene
{
	[self.delegate.parser updateOutline];
    return [self sortedTagsInRange:scene.range];
}

- (NSArray<OutlineScene*>*)scenesForTagDefinition:(TagDefinition*)tag
{
    NSMutableArray<OutlineScene*>* scenes = NSMutableArray.new;
    
    for (OutlineScene* scene in self.delegate.parser.scenes) {
        NSArray* tags = [self tagsInRange:scene.range];
        if ([tags containsObject:tag]) [scenes addObject:scene];
    }
    
    return scenes;
}

- (NSDictionary*)tagsByType {
	// This could be used to attach tags to corresponding IDs
	NSDictionary *tags = [BeatTagging tagDictionary];
	
	for (OutlineScene *scene in _delegate.parser.scenes) {
		NSDictionary *sceneTags = [self tagsForScene:scene];
		
		for (NSString *key in sceneTags.allKeys) {
			NSArray *taggedItems = sceneTags[key];
			NSMutableArray *allItems = tags[key];
			
			for (TagDefinition *item in taggedItems) {
				if (![allItems containsObject:item]) [allItems addObject:item];
			}
		}
	}
	
	return tags;
}

- (void)bakeTags {
    NSAttributedString *string = _delegate.attributedString;
	[BeatTagging bakeAllTagsInString:string toLines:self.delegate.parser.lines];
}

#pragma mark - UI methods for displaying tags in editor

- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene {
	if (!scene) return [[NSAttributedString alloc] initWithString:@""];
	
	NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:[self tagsForScene:scene]];
	NSMutableAttributedString *result = NSMutableAttributedString.new;
	
	[result appendAttributedString:[self boldedString:scene.stringForDisplay.uppercaseString color:nil]];
	[result appendAttributedString:[self str:@"\n\n"]];
	
	NSInteger headingLength = result.length;
	 
	// Get location
	NSString *location = scene.stringForDisplay;
	Rx *rx = [Rx rx:@"^(int|ext)" options:NSRegularExpressionCaseInsensitive];
	if ([location isMatch:rx]) {
		NSRange preRange = [location rangeOfString:@" "];
		location = [location substringFromIndex:preRange.location];
	}
	if ([location rangeOfString:@" - "].location != NSNotFound) {
		location = [location substringWithRange:(NSRange){0, [location rangeOfString:@" - "].location}];
	}
	location = [location stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	[result appendAttributedString:[self boldedString:@"Location\n" color:nil]];
	[result appendAttributedString:[self str:location]];
	[result appendAttributedString:[self str:@"\n\n"]];
	
	// List cast first
	NSArray *cast = tags[@"Cast"];
	if (cast.count) {
		[result appendAttributedString:[BeatTagging styledListTagFor:@"Cast" color:TagColor.whiteColor]];
		
		for (TagDefinition *tag in cast) {
			[result appendAttributedString:[self str:tag.name]];
			[result appendAttributedString:[self str:@"\n"]];
			if (cast.lastObject == tag) [result appendAttributedString:[self str:@"\n"]];
		}

		tags[@"Cast"] = nil; // Reset so we don't iterate over it again later
	}
	
	for (NSString* tagKey in tags.allKeys) {
		NSArray *items = tags[tagKey];
		if (items.count) {
			[result appendAttributedString:[BeatTagging styledListTagFor:tagKey color:TagColor.whiteColor]];
			
			for (TagDefinition *tag in items) {
				[result appendAttributedString:[self str:tag.name]];
				[result appendAttributedString:[self str:@"\n"]];
				
				if (items.lastObject == tag) [result appendAttributedString:[self str:@"\n"]];
			}
		}
	}
	
	if (result.length == headingLength) {
		[result appendAttributedString:[self string:@"No tagging data. Select a range in the screenplay to start tagging." withColor:TagColor.systemGrayColor]];
	}
	
	return result;
}

// String helpers
- (NSAttributedString*)str:(NSString*)string {
	return [self string:string withColor:TagColor.whiteColor];
}
- (NSAttributedString*)string:(NSString*)string withColor:(TagColor*)color {
	if (!color) color = TagColor.whiteColor;
	return [[NSAttributedString alloc] initWithString:string attributes:@{ NSFontAttributeName: [TagFont systemFontOfSize:UIFontSize], NSForegroundColorAttributeName: color }];
}
- (NSAttributedString*)boldedString:(NSString*)string color:(TagColor*)color {
	if (!color) color = TagColor.whiteColor;
	return [[NSAttributedString alloc] initWithString:string attributes:@{ NSFontAttributeName: [TagFont boldSystemFontOfSize:UIFontSize], NSForegroundColorAttributeName: color }];
}


#pragma mark - Actual tagging

- (BeatTag*)addTag:(NSString*)name type:(BeatTagType)type {
	if (type == NoTag) return nil;
	
	TagDefinition *def = [self searchForTag:name type:type];
	
	if (!def) return [self newTag:name type:type];
	else return [self newTagWithDefinition:def];
}

- (BeatTag*)newTag:(NSString*)name type:(BeatTagType)type {
	name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (type == CharacterTag) name = name.uppercaseString;
	
	TagDefinition *def = [[TagDefinition alloc] initWithName:name type:type identifier:[BeatTagging newId]];
	[_tagDefinitions addObject:def];
	
	return [BeatTag withDefinition:def];
}

- (BeatTag*)newTagWithDefinition:(TagDefinition*)def {
	return [BeatTag withDefinition:def];
}

- (TagDefinition*)definitionWithName:(NSString*)name type:(BeatTagType)type {
	for (TagDefinition* def in self.tagDefinitions) {
		if (def.type != type) continue;
		if ([def.name isEqualToString:name]) return def;
	}
	return nil;
}

+ (NSString*)newId {
	NSUUID *uuid = [NSUUID UUID];
	return [uuid UUIDString].lowercaseString;
}

- (TagDefinition*)searchForTag:(NSString*)string type:(BeatTagType)type
{
	string = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	for (TagDefinition *tag in _tagDefinitions) {
		if (tag.type == type && [tag.name.lowercaseString isEqualToString:string.lowercaseString]) return tag;
	}
	
	return nil;
}

/// Returns an array of tags that fit both the search string and type. It uses Levenshtein algorithm, so results include things that *somehow* contain the string.
- (NSArray<TagDefinition*>*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type
{
	NSMutableArray *matches = [NSMutableArray array];
	
	string = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	for (TagDefinition *tag in _tagDefinitions) {
		// Ignore stuff that isn't this type
		if (tag.type != type) continue;
		
		// Calculate Levenshtein distance
		CGFloat distance = [string compareWithString:tag.name];
		TagSearchResult *result = [TagSearchResult.alloc initWith:tag.name distance:distance];
		[matches addObject:result];
	}
	
	// Sort results using Levenshtein algorithm
	if (matches.count) [matches sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"distance" ascending:YES]]];
	
	// Convert results to strings
	NSMutableArray *matchStrings = NSMutableArray.array;
	for (TagSearchResult *result in matches) {
		[matchStrings addObject:result.string];
	}
	
	return matchStrings;
}

- (bool)tagDefinitionExists:(NSString*)string type:(BeatTagType)type
{
    return ([self searchForTag:string type:type] != nil);
}

/// Returns an array for saving the tags for converting to JSON.
- (NSArray<NSDictionary<NSString*,id>*>*)serializedTagData
{
    NSMutableArray *tagsToSave = NSMutableArray.new;
    NSArray *tags = [self allTags];
    
    for (BeatTag* tag in tags) {
        [tagsToSave addObject:@{
            @"range": @[ @(tag.range.location), @(tag.range.length) ],
            @"type": tag.key,
            @"definition": tag.defId
        }];
    }
    
    return tagsToSave;
}

/// Returns dictionary values for used definitions
- (NSArray<TagDefinition*>*)getDefinitions
{
	NSArray *allTags = [self allTags];
	NSMutableArray *defs = [NSMutableArray array];
	
	for (BeatTag* tag in allTags) {
		if (![defs containsObject:tag.definition]) [defs addObject:tag.definition];
	}
	
	NSMutableArray *defsToSave = [NSMutableArray array];
	for (TagDefinition *def in defs) {
		[defsToSave addObject:@{
			@"name": def.name,
			@"type": [BeatTagging keyFor:def.type],
			@"id": def.defId
		}];
	}
	
	return defsToSave;
}
+ (NSMutableArray<TagDefinition*>*)definitionsForTags:(NSArray<BeatTag*>*)tags
{
    NSMutableArray<TagDefinition*>* defs = NSMutableArray.new;
	
	for (BeatTag *tag in tags) {
		if (![defs containsObject:tag.definition]) [defs addObject:tag.definition];
	}
	
	return defs;
}

- (NSArray<TagDefinition*>*)definitionsForKey:(NSString*)key {
    NSMutableArray<TagDefinition*>* tags = NSMutableArray.new;
	BeatTagType type = [BeatTagging tagFor:key];
	
	for (TagDefinition *def in _tagDefinitions) {
		if (def.type == type) [tags addObject:def];
	}
	
	return tags;
}

- (BeatTagType)typeForId:(NSString*)defId {
	for (TagDefinition *def in _tagDefinitions) {
		if ([def hasId:defId]) return def.type;
	}
	return NoTag;
}

- (TagDefinition*)definitionFor:(BeatTag*)tag {
	return [self definitionForId:tag.defId];
}

- (TagDefinition*)definitionForId:(NSString*)defId {
	for (TagDefinition *def in _tagDefinitions) {
		if ([def.defId isEqualToString:defId]) return def;
	}
	return nil;
}


#pragma mark - Saving into external Fountain file

/// Get tags and definitions from an external attributed string
+ (NSDictionary*)tagsAndDefinitionsFrom:(NSAttributedString*)attrStr
{
    NSArray *tags = [BeatTagging allTagsFrom:attrStr];
    
    NSMutableArray *definitions = NSMutableArray.new;
    
    NSMutableArray *tagsToSave = NSMutableArray.new;
    NSMutableArray *defsToSave = NSMutableArray.new;
    
    for (BeatTag* tag in tags) {
        [tagsToSave addObject:@{
            @"range": @[ @(tag.range.location), @(tag.range.length) ],
            @"type": tag.key,
            @"definition": tag.defId
        }];
        
        if (![definitions containsObject:tag.definition]) {
            [definitions addObject:tag.definition];
        }
    }
    
    for (TagDefinition *def in definitions) {
        [defsToSave addObject:@{
            @"name": def.name,
            @"type": [BeatTagging keyFor:def.type],
            @"id": def.defId
        }];
    }
	
	return @{
        @"definitions": defsToSave,
        @"taggedRanges": tagsToSave
	};
}


#pragma mark - Editor methods

- (void)removeAllTags
{
    NSTextStorage* textStorage = self.delegate.textStorage;
    [textStorage removeAttribute:BeatTagging.attributeKey range:NSMakeRange(0, textStorage.length)];
    
    [self.delegate.getTextView textViewNeedsDisplay];
}

/// Tags a range in editor with tag type, taking the tag definition name from selected range.
- (void)tagRange:(NSRange)range withType:(BeatTagType)type
{
	NSString *string = [self.delegate.text substringWithRange:range];
	BeatTag* tag = [self addTag:string type:type];
	
	if (tag) {
		[self tagRange:range withTag:tag];
		[self.delegate.formatting forceFormatChangesInRange:range];
	}
}

/// Tags a range in editor with given definition
- (void)tagRange:(NSRange)range withDefinition:(TagDefinition*)definition
{
    BeatTag *tag = [BeatTag withDefinition:definition];

	[self tagRange:range withTag:tag];
	[self.delegate.formatting forceFormatChangesInRange:range];
}

/// Tag a range with the specified single tag.
- (void)tagRange:(NSRange)range withTag:(BeatTag*)tag
{
    range = CLAMP_RANGE(range, self.delegate.text.length);
    if (range.length == 0) return;
    
    NSAttributedString* oldAttributedString = self.delegate.attributedString;
	
    // Start editing text storage
    if (!_delegate.documentIsLoading) [_delegate.textStorage beginEditing];
    
    // Either add or remove the tag from text. Tagging a range with nil tag means that we're clearing the range.
	if (tag == nil) {
		[_delegate.textStorage removeAttribute:BeatTagging.attributeKey range:range];
	} else {
		[_delegate.textStorage addAttribute:BeatTagging.attributeKey value:tag range:range];
	}
    
    // Save tags to document settings again
    [self saveTags];
	
    // If we're still loading, we'll stop here
    if (_delegate.documentIsLoading) return;
    
    // End editing of text storage
    [_delegate.textStorage endEditing];

    // Post a notification that tags have changed
    [NSNotificationCenter.defaultCenter postNotificationName:BeatTagging.notificationName object:self.delegate];
    
	// If document is not loading, set undo states and post a notification
    // TODO: Save previous attributes (see how parts of undoing work in revision manager)
    [self.delegate.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		NSLog(@"# NOTE: Test this before making tagging public.");
		[self.delegate.textStorage removeAttribute:BeatTagging.attributeKey range:range];
		[oldAttributedString enumerateAttribute:BeatTagging.attributeKey inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange tRange, BOOL * _Nonnull stop) {
			if (value == nil) return;
			
			[self.delegate.textStorage addAttribute:BeatTagging.attributeKey value:value range:tRange];
		}];
	}];
}

- (void)saveTags
{
    NSArray<NSDictionary*>* tags = self.serializedTagData;
	NSArray* definitions = [self getDefinitions];
	
	[_delegate.documentSettings set:DocSettingTags as:tags];
	[_delegate.documentSettings set:DocSettingTagDefinitions as:definitions];
}

- (void)updateTaggingData 
{
    NSAttributedString* tagInfo = [self displayTagsForScene:self.delegate.currentScene];
    [self.tagTextView.textStorage setAttributedString:tagInfo];
}


#pragma mark - Editor actions

- (IBAction)toggleTagging:(id)sender {
	[_delegate toggleMode:TaggingMode];
}

- (IBAction)closeTagging:(id)sender {
    [_delegate toggleMode:EditMode];
}

@end
