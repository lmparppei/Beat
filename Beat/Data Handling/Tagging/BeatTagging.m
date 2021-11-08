//
//  BeatTagging.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Minimal tagging implementation. This relies on adding attributes into the NSTextView string,
 and tagging data is NOT present in the screenplay text. It is saved as a separate JSON string
 inside the document settings.
 
 We have two classes, BeatTag and TagDefinition (sorry for the inconsistence). BeatTags are
 added as attributes to the string (attribute name "BeatTag"), and they contain a reference
 to their definition. Definitions are created on the fly and get their text content from
 the first time something is tagged.
 
 This is similar to the Final Draft implementation, but for now, Beat doesn't allow
 choosing from a list of previous definitions or editing them directly.
 
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

#import <Cocoa/Cocoa.h>
#import "BeatTagging.h"
#import "RegExCategories.h"
#import "BeatTagItem.h"
#import "BeatTag.h"
#import "NSString+Levenshtein.h"

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
@property (nonatomic) NSMutableArray *tagDefinitions;
@property (nonatomic) OutlineScene *lastScene;
@end

@implementation BeatTagging

- (instancetype)initWithDelegate:(id<BeatTaggingDelegate>)delegate {
	self = [super init];
	if (self) {
		self.delegate = delegate;
	}
	
	return self;
}

+ (NSArray*)tags {
	return @[@"Cast", @"Prop", @"Costume", @"Makeup", @"VFX", @"Animal", @"Extras", @"Vehicle"];
}
+ (NSArray*)styledTags {
	NSArray *tags = BeatTagging.tags;
	NSMutableArray *styledTags = [NSMutableArray array];
	
	// Add menu item to remove current tag
	[styledTags addObject:[[NSAttributedString alloc] initWithString:@"× None"]];
	
	for (NSString *tag in tags) {
		[styledTags addObject:[self styledTagFor:tag]];
	}
	
	return styledTags;
}
+ (NSAttributedString*)styledTagFor:(NSString*)tag {
	NSColor *color = [(NSDictionary*)[BeatTagging tagColors] valueForKey:tag];
	
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"● %@", tag]];
	if (color) [string addAttribute:NSForegroundColorAttributeName value:color range:(NSRange){0, 1}];
	return string;
}
+ (NSAttributedString*)styledListTagFor:(NSString*)tag color:(NSColor*)textColor {
	NSColor *color = [(NSDictionary*)[BeatTagging tagColors] valueForKey:tag];
	
	NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
	paragraph.paragraphSpacing = 3.0;
	
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"● %@\n", tag]];
	if (color) [string addAttribute:NSForegroundColorAttributeName value:color range:(NSRange){0, 1}];
	[string addAttribute:NSForegroundColorAttributeName value:textColor range:(NSRange){1, string.length - 1}];
	[string addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:UIFontSize] range:(NSRange){0, string.length}];
	[string addAttribute:NSParagraphStyleAttributeName value:paragraph range:(NSRange){0, string.length}];
	[string addAttribute:@"TagTitle" value:@"Yes" range:(NSRange){0, string.length - 1}];
	return string;
}
+ (NSDictionary*)tagColors
{
	return @{
		@"Cast": [BeatColors color:@"cyan"],
		@"Prop": [BeatColors color:@"orange"],
		@"Costume": [BeatColors color:@"pink"],
		@"Makeup": [BeatColors color:@"green"],
		@"VFX": [BeatColors color:@"purple"],
		@"Animal": [BeatColors color:@"yellow"],
		@"Extras": [BeatColors color:@"magenta"],
		@"Vehicle": [BeatColors color:@"teal"],
		@"Special Effect": [BeatColors color:@"brown"],
		@"Generic": [BeatColors color:@"gray"]
	};
}

+ (BeatTagType)tagFor:(NSString*)tag
{
	// Make the tag lowercase for absolute compatibility
	tag = tag.lowercaseString;
	if ([tag isEqualToString:@"cast"]) return CharacterTag;
	else if ([tag isEqualToString:@"prop"]) return PropTag;
	else if ([tag isEqualToString:@"vfx"]) return VFXTag;
	else if ([tag isEqualToString:@"special effect"]) return SpecialEffectTag;
	else if ([tag isEqualToString:@"animal"]) return AnimalTag;
	else if ([tag isEqualToString:@"extras"]) return ExtraTag;
	else if ([tag isEqualToString:@"vehicle"]) return VehicleTag;
	else if ([tag isEqualToString:@"costume"]) return CostumeTag;
	else if ([tag isEqualToString:@"makeup"]) return MakeupTag;
	else if ([tag isEqualToString:@"music"]) return MusicTag;
	else if ([tag isEqualToString:@"none"]) return NoTag;
	else { return GenericTag; }
}
+ (NSString*)keyFor:(BeatTagType)tag
{
	if (tag == CharacterTag) return @"Cast";
	else if (tag == PropTag) return @"Prop";
	else if (tag == VFXTag) return @"VFX";
	else if (tag == SpecialEffectTag) return @"Special Effect";
	else if (tag == AnimalTag) return @"Animal";
	else if (tag == ExtraTag) return @"Extras";
	else if (tag == VehicleTag) return @"Vehicle";
	else if (tag == CostumeTag) return @"Costume";
	else if (tag == MakeupTag) return @"Makeup";
	else if (tag == MusicTag) return @"Music";
	else if (tag == NoTag) return @"";
	else return @"Generic";
}
+ (NSColor*)colorFor:(BeatTagType)tag {
	NSDictionary *colors = [self tagColors];
	NSColor *color = [colors valueForKey:[self keyFor:tag]];
	if (!color) color = colors[@"generic"];
	
	return color;
}
+ (NSString*)hexForKey:(NSString*)key {
	NSColor *color = [self tagColors][key];
	return [BeatColors get16bitHex:color];
}

+ (NSDictionary*)tagDictionary {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *tags = [BeatTagging tags];
	
	for (NSString* tag in tags) {
		[dict setValue:[NSMutableArray array] forKey:tag];
	}

	return dict;
}
+ (NSMutableDictionary*)tagDictionaryWithDictionaries {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *tags = [BeatTagging tags];
	
	for (NSString* tag in tags) {
		[dict setValue:[NSMutableDictionary dictionary] forKey:tag];
	}

	return dict;
}

- (void)loadTags:(NSArray*)tags definitions:(NSArray*)definitions {	
	self.tagDefinitions = [NSMutableArray array];
	for (NSDictionary *dict in definitions) {
		TagDefinition *def = [[TagDefinition alloc] initWithName:dict[@"name"] type:[BeatTagging tagFor:dict[@"type"]] identifier:dict[@"id"]];
		[_tagDefinitions addObject:def];
	}
	
	for (NSDictionary* tag in tags) {
		if (![tag isKindOfClass:NSDictionary.class]) {
			NSLog(@"Tagging: Ignoring old tag %@", tag);
			continue;
		}
		
		NSArray *rangeValues = tag[@"range"];
		if (rangeValues.count < 2) continue; // Ignore faulty values
		
		NSInteger loc = [(NSNumber*)rangeValues[0] integerValue];
		NSInteger len = [(NSNumber*)rangeValues[1] integerValue];
		
		NSRange range = (NSRange){ loc, len };
		
		TagDefinition *def = [self definitionForId:tag[@"definition"]];
		BeatTag *newTag = [BeatTag withDefinition:def];
		
		if (range.length > 0) {
			[self.delegate tagRange:range withTag:newTag];
		}
	}
}

+ (void)bakeAllTagsInString:(NSAttributedString*)textViewString toLines:(NSArray*)lines
{
	/*
	 
	 This bakes the tag items into lines. The lines then retain the references to the tag items,
	 which we carry on to FDX export.
	 
	 */

	for (Line *line in lines) {
		if (line.range.length == 0 || line.string.length == 0) continue;
		
		line.tags = [NSMutableArray array];

		/*
		// Somehow bake characters automatically
		if (line.type == character) {

		}
		 */
		
		// Local string from the attributed content using line range
		if (line.range.location >= textViewString.length) break;
		NSAttributedString *string = [textViewString attributedSubstringFromRange:line.textRange];
		
		// Enumerate through tags in the attributed string		
		[string enumerateAttribute:@"BeatTag" inRange:(NSRange){0, line.string.length} options:0 usingBlock:^(id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			BeatTag *tag = (BeatTag*)value;
			
			if (!tag || range.length == 0) return;
						
			[line.tags addObject:@{
				@"tag": tag,
				@"range": [NSValue valueWithRange:range]
			}];
		}];
	}
}

- (NSArray*)allTags {
	NSMutableArray *tags = [NSMutableArray array];
	NSAttributedString *string = [[NSAttributedString alloc] initWithAttributedString:self.delegate.textView.attributedString];
	
	[string enumerateAttribute:@"BeatTag" inRange:(NSRange){0, string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatTag *tag = (BeatTag*)value;
		if (tag.type == NoTag) return; // Just in case
		
		// Save current range of the tag into the object and add to array
		tag.range = range;
		[tags addObject:tag];
	}];
	
	return tags;
}

- (NSDictionary*)sortedTagsInRange:(NSRange)searchRange {
	NSDictionary *tags = [BeatTagging tagDictionary];
	NSAttributedString *string = [[NSAttributedString alloc] initWithAttributedString:self.delegate.textView.attributedString];
	
	[string enumerateAttribute:@"BeatTag" inRange:searchRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatTag *tag = (BeatTag*)value;
		
		if (tag.type == NoTag) return;
		tag.range = range;
		
		// Add definition to array if it's not present yet
		if (tag.definition) {
			NSMutableArray *tagDefinitions = tags[tag.key];
			if (![tagDefinitions containsObject:tag.definition]) [tagDefinitions addObject:tag.definition];
		}
	}];
	
	return tags;
}

- (NSDictionary*)tagsForScene:(OutlineScene*)scene {
	[self.delegate.parser createOutline];
	
	NSDictionary *tags = [self sortedTagsInRange:scene.range];
	NSArray *lines = [self.delegate.parser linesForScene:scene];
	
	NSMutableArray *castTags = tags[@"Cast"];
	
	for (Line* line in lines) {
		if (line.type == character) {
			NSString *name = line.characterName.uppercaseString;
			BeatTag *characterTag = [self addTag:name type:CharacterTag];
			
			if (![castTags containsObject:characterTag.definition]) [castTags addObject:characterTag.definition];
		}
	}
	
	return tags;
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
	[BeatTagging bakeAllTagsInString:self.delegate.textView.attributedString toLines:self.delegate.parser.lines];
	//[BeatTagging bakeTags:[self individualTags] inString:self.delegate.textView.attributedString toLines:self.delegate.parser.lines];
}

#pragma mark - UI methods for displaying tags in editor

- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene {
	if (!scene) return [[NSAttributedString alloc] initWithString:@""];
	
	NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:[self tagsForScene:scene]];
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
	
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
		[result appendAttributedString:[BeatTagging styledListTagFor:@"Cast" color:NSColor.whiteColor]];
		
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
			[result appendAttributedString:[BeatTagging styledListTagFor:tagKey color:NSColor.whiteColor]];
			
			for (TagDefinition *tag in items) {
				[result appendAttributedString:[self str:tag.name]];
				[result appendAttributedString:[self str:@"\n"]];
				
				if (items.lastObject == tag) [result appendAttributedString:[self str:@"\n"]];
			}
		}
	}
	
	if (result.length == headingLength) {
		[result appendAttributedString:[self string:@"No tagging data. Select a range in the screenplay to start tagging." withColor:NSColor.systemGrayColor]];
	}
	
	return result;
}

- (void)setupTextView:(NSTextView*)textView {
	textView.textContainerInset = (NSSize){ 8, 8 };
}

// String helpers
- (NSAttributedString*)str:(NSString*)string {
	return [self string:string withColor:NSColor.whiteColor];
}
- (NSAttributedString*)string:(NSString*)string withColor:(NSColor*)color {
	if (!color) color = NSColor.whiteColor;
	return [[NSAttributedString alloc] initWithString:string attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:UIFontSize], NSForegroundColorAttributeName: color }];
}
- (NSAttributedString*)boldedString:(NSString*)string color:(NSColor*)color {
	if (!color) color = NSColor.whiteColor;
	return [[NSAttributedString alloc] initWithString:string attributes:@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:UIFontSize], NSForegroundColorAttributeName: color }];
}

#pragma mark - New Tagging

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

- (TagDefinition*)searchForTag:(NSString*)string type:(BeatTagType)type {
	string = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	for (TagDefinition *tag in _tagDefinitions) {
		if (tag.type == type && [tag.name.lowercaseString isEqualToString:string.lowercaseString]) return tag;
	}
	
	return nil;
}
- (NSArray<TagDefinition*>*)searchTagsByTerm:(NSString*)string type:(BeatTagType)type {
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
- (bool)tagExists:(NSString*)string type:(BeatTagType)type {
	if ([self searchForTag:string type:type] != nil) return YES; else return NO;
}

- (NSArray*)getTags {
	// Returns an array for saving the tags
	NSMutableArray *tagsToSave = [NSMutableArray array];
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
- (NSArray*)getDefinitions {
	// Returns dictionary values for used definitions
	
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
+ (NSArray*)definitionsForTags:(NSArray*)tags {
	NSMutableArray *defs = [NSMutableArray array];
	
	for (BeatTag *tag in tags) {
		if (![defs containsObject:tag.definition]) [defs addObject:tag.definition];
	}
	
	return defs;
}

- (NSArray*)definitionsForKey:(NSString*)key {
	NSMutableArray *tags = [NSMutableArray array];
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

@end
