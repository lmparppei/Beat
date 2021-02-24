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
#import "ContinousFountainParser.h"

NS_ASSUME_NONNULL_BEGIN

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
} BeatTag;

@protocol BeatTaggingDelegate <NSObject>
@property (readonly, weak) ContinousFountainParser *parser;
@property (readonly, weak) NSTextView *textView;
@property (readonly) bool taggingMode;
- (void)tagRange:(NSRange)range withTag:(BeatTag)tag;
@end

@interface BeatTagging : NSObject
@property (weak) id<BeatTaggingDelegate> delegate;

+ (NSArray*)tags;
+ (BeatTag)tagFor:(NSString*)tag;
+ (NSDictionary*)taggedRangesIn:(NSAttributedString*)string;
+ (NSArray*)styledTags;
+ (void)bakeTags:(NSArray*)tags inString:(NSAttributedString*)textViewString toLines:(NSArray*)lines;
+ (NSDictionary*)tagColors;
+ (NSColor*)colorFor:(BeatTag)tag;

- (instancetype)initWithDelegate:(id<BeatTaggingDelegate>)delegate;
- (void)setRanges:(NSDictionary*)tags;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (void)bakeTags;
- (NSArray*)individualTags;
- (NSAttributedString*)displayTagsForScene:(OutlineScene*)scene;
- (void)setupTextView:(NSTextView*)textView;

@end

NS_ASSUME_NONNULL_END
