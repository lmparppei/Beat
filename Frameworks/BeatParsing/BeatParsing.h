//
//  BeatParsing.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.10.2022.
//

#ifndef BeatParsing_h
#define BeatParsing_h
#pragma clang system_header

#import <BeatParsing/ContinuousFountainParser.h>
#import <BeatParsing/ContinuousFountainParser+Preprocessing.h>
#import <BeatParsing/ContinuousFountainParser+Outline.h>
#import <BeatParsing/ContinuousFountainParser+Omissions.h>
#import <BeatParsing/ContinuousFountainParser+Lookup.h>
#import <BeatParsing/ContinuousFountainParser+Macros.h>

#import <BeatParsing/Line.h>
#import <BeatParsing/Line+Type.h>
#import <BeatParsing/Line+ConvenienceTypeChecks.h>
#import <BeatParsing/Line+AttributedStrings.h>
#import <BeatParsing/Line+Storybeats.h>
#import <BeatParsing/Line+Notes.h>
#import <BeatParsing/Line+RangeLookup.h>
#import <BeatParsing/Line+SplitAndJoin.h>

#import <BeatParsing/OutlineScene.h>
#import <BeatParsing/FountainRegexes.h>
#import <BeatParsing/BeatDocumentSettings.h>
#import <BeatParsing/BeatDocumentSettings+Shorthands.h>

#import <BeatParsing/RegExCategories.h>
#import <BeatParsing/NSString+CharacterControl.h>
#import <BeatParsing/NSString+Regex.h>
#import <BeatParsing/NSMutableString+Regex.h>
#import <BeatParsing/NSArray+BinarySearch.h>

#import <BeatParsing/NSCharacterSet+BadControlCharacters.h>
#import <BeatParsing/NSString+EMOEmoji.h>

#import <BeatParsing/NSDictionary+Values.h>
#import <BeatParsing/NSIndexSet+Subset.h>
#import <BeatParsing/NSMutableIndexSet+Lowest.h>

#import <BeatParsing/ParsingRule.h>

#import <BeatParsing/NSMutableAttributedString+BeatAttributes.h>

#endif /* BeatParsing_h */
