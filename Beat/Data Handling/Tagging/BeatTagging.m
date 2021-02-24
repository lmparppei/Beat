//
//  BeatTagging.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 6.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//
/*
 
 Minimal tagging support implementation. This relies on kind of a hack. We add tag attributes to the
 string inside NSTextView alongside some stylization. The parser doesn't care about tagging data, and
 it's saved to a separate JSON string inside the document settings.
 
 It's not the most robust and reliable system, but keeps the Fountain file readable in any other
 Fountain editor while allowing tags to be exported straight into the FDX file.
 
 
 Notes on moving tags to FDX:

 IDEAS:
 For transporting tags into FDX conversion and baking them into tag, NSMutableIndexSets would be
 a more feasible solution. Then just enumerate through them when creating the attributed string.
 
 @{
	@"Cast": NSMutableIndexSet,
	...
 };
 
 I have no energy to do this right now.
 
 */

#import <Cocoa/Cocoa.h>
#import "BeatTagging.h"

#define UIFontSize 11.0

@interface BeatTagging ()
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
		@"Vehicle": [BeatColors color:@"brown"],
		@"Generic": [BeatColors color:@"gray"]
	};
}

+ (BeatTag)tagFor:(NSString*)tag
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
+ (NSString*)keyFor:(BeatTag)tag
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
+ (NSColor*)colorFor:(BeatTag)tag {
	NSDictionary *colors = [self tagColors];
	return [colors valueForKey:[self keyFor:tag]];
}

+ (NSDictionary*)tagDictionary {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *tags = [BeatTagging tags];
	
	for (NSString* tag in tags) {
		[dict setValue:[NSMutableArray array] forKey:tag];
	}

	return dict;
}
+ (NSDictionary*)taggedRangesIn:(NSAttributedString*)string
{
	NSDictionary *dict = [BeatTagging tagDictionary];
	
	[string enumerateAttribute:@"BeatTag" inRange:(NSRange){0, string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) {
			BeatTag tag = (BeatTag)[value integerValue];
			
			NSArray *ranges = @[ @(range.location), @(range.length) ];

			NSString* tagKey = [self keyFor:tag];
			[dict[tagKey] addObject:ranges];
		}
	}];
	
	return dict;
}

- (void)setRanges:(NSDictionary*)tags {
	for (NSString *key in tags.allKeys) {
		BeatTag tag = [BeatTagging tagFor:key];
		NSArray* ranges = (NSArray*)tags[key];
		
		for (NSArray *values in ranges) {
			// For safety reasons, ignore non-array values
			if (![values isKindOfClass:NSArray.class] || values.count < 2) continue;
			
			NSInteger loc = [(NSNumber*)values[0] integerValue];
			NSInteger len = [(NSNumber*)values[1] integerValue];
			
			if (len > 0) {
				NSRange range = NSMakeRange(loc, len);
				[self.delegate tagRange:range withTag:tag];
			}
		}
	}
}

- (NSArray*)individualTags {
	NSMutableArray *tags = [NSMutableArray array];
	
	NSAttributedString *string = [[NSAttributedString alloc] initWithAttributedString:self.delegate.textView.attributedString];
	[string enumerateAttribute:@"BeatTag" inRange:(NSRange){0, string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatTag tag = (BeatTag)[value integerValue];
		NSString *string = [self.delegate.textView.string substringWithRange:range];
		
		if (range.length > 0 && tag != NoTag) {
			NSDictionary *data = @{
				@"tag": [BeatTagging keyFor:tag],
				@"string": string,
				@"range": [NSValue valueWithRange:range]
			};
			[tags addObject:data];
		}
	}];
	
	return tags;
}

- (NSDictionary*)tagsInRange:(NSRange)searchRange {
	NSDictionary *tags = [BeatTagging tagDictionary];
	NSAttributedString *string = [[NSAttributedString alloc] initWithAttributedString:self.delegate.textView.attributedString];
	[string enumerateAttribute:@"BeatTag" inRange:searchRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		
		BeatTag tag = (BeatTag)[value integerValue];
		if (range.length > 0 && tag != NoTag) {
			NSString *key = [BeatTagging keyFor:tag];
			NSString *string = [self.delegate.textView.string substringWithRange:range];
			
			// Make cast members UPPERCASE
			if (tag == CharacterTag) string = string.uppercaseString;
			
			NSMutableArray *tagArray = (NSMutableArray*)tags[key];
			if (![tagArray containsObject:string]) {
				[tagArray addObject:string];
			}
		}
	}];
	
	return tags;
}

- (NSDictionary*)tagsForScene:(OutlineScene*)scene {
	[self.delegate.parser createOutline];
	
	NSDictionary *tags = [self tagsInRange:scene.range];
	NSArray *lines = [self.delegate.parser linesForScene:scene];
	
	for (Line* line in lines) {
		if (line.type == character) {
			NSString *name = line.characterName.uppercaseString;
			if (![(NSMutableArray*)tags[@"Cast"] containsObject:name]) [tags[@"Cast"] addObject:name];
		}
	}
	
	return tags;
}

+ (void)bakeTags:(NSArray*)tags inString:(NSAttributedString*)textViewString toLines:(NSArray*)lines
{
	// This writes tags into line elements
	for (Line* line in lines) {
		line.tags = [NSMutableArray array];
		
		// Automatically add any character names
		if (line.type == character) {
			NSString *name = line.characterName;
			[line.tags addObject:@{
				@"tag": [BeatTagging keyFor:CharacterTag],
				@"name": @"Cast",
				@"range": [NSValue valueWithRange:[line.string rangeOfString:name]]
			}];
			
			continue;
		}
		
		// Go through the attributed string and add tags found in the stylization
		NSAttributedString *string = [textViewString attributedSubstringFromRange:(NSRange){ line.position, line.string.length }];
		[string enumerateAttribute:@"BeatTag" inRange:(NSRange){0, line.string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			BeatTag tag = (BeatTag)[value integerValue];
			
			if (range.length > 0 && tag != NoTag) {

				for (NSDictionary *tag in tags) {
					NSRange range = [(NSValue*)[tag valueForKey:@"range"] rangeValue];
					
					// We should probably remove tags from the array after use, but whatever
					if (NSLocationInRange(range.location, line.range)) {
						NSMutableDictionary *localTag = [NSMutableDictionary dictionaryWithDictionary:[tag copy]];
												
						// Create a local range in line from the global range
						NSRange localRange = (NSRange){ range.location - line.range.location, range.length };
						localTag[@"range"] = [NSValue valueWithRange:localRange];
						[line.tags addObject:localTag];
					}
				}
			}
		}];
	}
	
	
}

- (void)bakeTags {
	[BeatTagging bakeTags:[self individualTags] inString:self.delegate.textView.attributedString toLines:self.delegate.parser.lines];
}

- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene {
	NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:[self tagsForScene:scene]];
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
	
	[result appendAttributedString:[self boldedString:scene.stringForDisplay color:nil]];
	[result appendAttributedString:[self str:@"\n\n"]];
	
	NSInteger headingLength = result.length;
	
	NSArray *cast = tags[@"Cast"];
	if (cast.count) {
		[result appendAttributedString:[BeatTagging styledListTagFor:@"Cast" color:NSColor.whiteColor]];
		for (NSString *name in (NSArray*)tags[@"Cast"]) {
			[result appendAttributedString:[self str:name]];
			[result appendAttributedString:[self str:@"\n"]];
		}
		
		tags[@"Cast"] = nil;
		[result appendAttributedString:[self str:@"\n"]];
	}
	
	for (NSString* tag in tags.allKeys) {
		NSArray *items = tags[tag];
		if (items.count) {
			[result appendAttributedString:[BeatTagging styledListTagFor:tag color:NSColor.whiteColor]];
			[result appendAttributedString:[self str:[items componentsJoinedByString:@"\n"]]];
			[result appendAttributedString:[self str:@"\n\n"]];
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

@end
