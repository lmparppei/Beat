//
//  ParsingRule.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.12.2024.
//

#import "ParsingRule.h"
#import <BeatParsing/Line+Type.h>
#import <BeatParsing/NSString+CharacterControl.h>

@implementation ParsingRule

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                      previousIsEmpty:(BOOL)previousIsEmpty
                         previousTypes:(NSArray<NSNumber *> *)previousTypes
                allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:0 minimumLengthAtInput:0 previousIsEmpty:previousIsEmpty previousTypes:previousTypes allCapsUntilParentheses:allCapsUntilParentheses exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 titlePage:false];
}

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                               length:(NSInteger)length
                    allowedWhiteSpace:(NSInteger)allowedWhiteSpace
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:0 minimumLengthAtInput:0 previousIsEmpty:false previousTypes:nil allCapsUntilParentheses:false exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:length allowedWhiteSpace:allowedWhiteSpace titlePage:false];
}

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                         exactMatches:(NSArray<NSString*>*)exactMatches
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:0 minimumLengthAtInput:0 previousIsEmpty:false previousTypes:nil allCapsUntilParentheses:false exactMatches:exactMatches beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 titlePage:false];
}

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                        minimumLength:(NSInteger)minimumLength
                 minimumLengthAtInput:(NSInteger)minimumLengthAtInput
                      previousIsEmpty:(BOOL)previousIsEmpty
                         previousTypes:(NSArray<NSNumber *> *)previousTypes
                allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:minimumLength minimumLengthAtInput:minimumLengthAtInput previousIsEmpty:previousIsEmpty previousTypes:previousTypes allCapsUntilParentheses:allCapsUntilParentheses exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 titlePage:false];
}

+ (instancetype)ruleWithResultingType:(LineType)resultingType previousIsEmpty:(BOOL)previousIsEmpty previousTypes:(NSArray<NSNumber *> *)previousTypes allCapsUntilParentheses:(BOOL)allCapsUntilParentheses beginsWith:(NSArray<NSString *> *)beginsWith endsWith:(NSArray<NSString *> *)endsWith requiredAfterPrefix:(NSArray<NSString *> *)requiredAfterPrefix excludedAfterPrefix:(NSArray<NSString *> *)excludedAfterPrefix
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:0 minimumLengthAtInput:0 previousIsEmpty:previousIsEmpty previousTypes:previousTypes allCapsUntilParentheses:allCapsUntilParentheses exactMatches:nil beginsWith:beginsWith endsWith:endsWith requiredAfterPrefix:requiredAfterPrefix excludedAfterPrefix:excludedAfterPrefix length:0 allowedWhiteSpace:0 titlePage:false];
}

+ (instancetype)ruleWithResultingType:(LineType)resultingType previousIsEmpty:(BOOL)previousIsEmpty previousTypes:(NSArray<NSNumber *> *)previousTypes allCapsUntilParentheses:(BOOL)allCapsUntilParentheses beginsWith:(NSArray<NSString *> *)beginsWith endsWith:(NSArray<NSString *> *)endsWith
{
    return [ParsingRule ruleWithResultingType:resultingType minimumLength:0 minimumLengthAtInput:0 previousIsEmpty:previousIsEmpty previousTypes:previousTypes allCapsUntilParentheses:allCapsUntilParentheses exactMatches:nil beginsWith:beginsWith endsWith:endsWith requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 titlePage:false];
}


+ (instancetype)ruleWithResultingType:(LineType)resultingType
                        minimumLength:(NSInteger)minimumLength
                 minimumLengthAtInput:(NSInteger)minimumLengthAtInput
                      previousIsEmpty:(BOOL)previousIsEmpty
                        previousTypes:(NSArray<NSNumber*>*)previousTypes
              allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
                         exactMatches:(NSArray<NSString*>*)exactMatches
                           beginsWith:(NSArray<NSString*>*)beginsWith
                             endsWith:(NSArray<NSString*>*)endsWith
                  requiredAfterPrefix:(NSArray<NSString*>*)requiredAfterPrefix
                  excludedAfterPrefix:(NSArray<NSString*>*)excludedAfterPrefix
                               length:(NSInteger)length
                    allowedWhiteSpace:(NSInteger)allowedWhiteSpace
                            titlePage:(BOOL)titlePage
{
    ParsingRule *rule = [[ParsingRule alloc] init];
    rule.resultingType = resultingType;
    
    rule.minimumLength = minimumLength;
    rule.minimumLengthAtInput = minimumLengthAtInput;
    
    rule.exactMatches = exactMatches;
    rule.previousIsEmpty = previousIsEmpty;
    rule.allCapsUntilParentheses = allCapsUntilParentheses;
    rule.beginsWith = beginsWith ?: @[];
    rule.endsWith = endsWith ?: @[];
    rule.requiredAfterPrefix = requiredAfterPrefix ?: @[];
    rule.excludedAfterPrefix = excludedAfterPrefix ?: @[];
    rule.length = length;
    rule.allowedWhiteSpace = allowedWhiteSpace;
    rule.titlePage = titlePage;
    
    NSMutableIndexSet *pTypes = [NSMutableIndexSet indexSet];
    for (NSNumber *typeNumber in previousTypes) {
        [pTypes addIndex:[typeNumber unsignedIntegerValue]];
    }
    rule.previousTypes = [pTypes copy];
    
    return rule;
}

- (BOOL)validate:(Line*)line previousLine:(Line*)previousLine
{
    bool previousIsEmpty = (previousLine.type == empty);
    
    // Basic rules
    if ((self.minimumLength > line.length) ||                                            // Min length requirement
        (self.length > 0 && line.length > self.length) ||                                // Max length requirement
        (self.previousIsEmpty && !previousIsEmpty) ||                                    // Previous is empty
        (self.allCapsUntilParentheses && !line.string.onlyUppercaseUntilParenthesis) ||  // All caps
        (line.string.containsOnlyWhitespace && line.length > self.allowedWhiteSpace)     // Only whitespace
        )
    {
        return false;
    }
    
    // Exact matches
    if (self.exactMatches.count > 0) {
        bool match = false;
        for (NSString* exactMatch in self.exactMatches) {
            if ([line.string isEqualToString:exactMatch]) match = true;
        }
        if (!match) return false;
    }
        
    if (previousLine != nil && self.previousTypes.count > 0 && ![self.previousTypes containsIndex:previousLine.type]) {
        return false;
    }
    else if (self.beginsWith.count > 0 && ![self matchesPrefix:line]) {
        return false;
    }
    else if (self.endsWith.count > 0 && ![self matchesSuffix:line]) {
        return false;
    }
    else if (self.titlePage && (previousLine.isTitlePage || previousLine == nil)) {
        // Parse title page here
        return false;
    }
    
    // We've passed all tests
    return true;
    
}

- (bool)matchesPrefix:(Line*)line
{
    NSString* string = line.string.lowercaseString;
    
    for (NSString* prefix in self.beginsWith) {
        if (![string hasPrefix:prefix]) continue;
        
        // Check for additional rules
        bool allowedCharacters = true;
        bool fulfillsRequirements = (self.requiredAfterPrefix.count > 0) ? false : true; // If there are no required items after prefix, this will always be true
        
        for (NSString* excluded in self.excludedAfterPrefix) {
            NSString* fullPrefix = [prefix stringByAppendingString:excluded];
            if ([string hasPrefix:fullPrefix]) {
                allowedCharacters = false;
                break;
            }
        }
        
        if (!allowedCharacters) continue;
        
        for (NSString* required in self.requiredAfterPrefix) {
            NSString* fullPrefix = [prefix stringByAppendingString:required];
            if ([string hasPrefix:fullPrefix]) fulfillsRequirements = true;
        }
        
        if (allowedCharacters && fulfillsRequirements) return true;
    }
    
    return false;
}

- (bool)matchesSuffix:(Line*)line
{
    NSString* trimmedString = line.string.trim;
    for (NSString* suffix in self.endsWith) {
        if ([trimmedString rangeOfString:suffix].location == trimmedString.length - suffix.length) return true;
    }
    return false;
}

@end
