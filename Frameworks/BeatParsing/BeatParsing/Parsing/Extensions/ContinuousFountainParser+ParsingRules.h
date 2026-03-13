//
//  ContinuousFountainParser+ParsingRules.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 8.3.2026.
//

#import <BeatParsing/BeatParsing.h>

@class ParsingRule;

@interface ContinuousFountainParser (ParsingRules)

+ (NSArray<ParsingRule*>* _Nonnull)rules;

@end
