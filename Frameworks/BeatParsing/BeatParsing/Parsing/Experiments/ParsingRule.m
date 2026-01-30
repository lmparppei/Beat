//
//  ParsingRule.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.12.2024.
//

#import "ParsingRule.h"
#import <BeatParsing/Line+Type.h>
#import <BeatParsing/NSString+CharacterControl.h>

#define mask_contains(mask, bit) (mask & bit) == bit

@implementation ParsingRule

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes
{
    return [ParsingRule type:resultingType options:options minimumLength:0 minimumLengthAtInput:0 previousTypes:previousTypes exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType options:(ParsingOptions)options minimumLength:(NSInteger)minimumLength previousTypes:(NSArray<NSNumber *> *)previousTypes {
    return [ParsingRule type:resultingType options:options minimumLength:minimumLength minimumLengthAtInput:0 previousTypes:previousTypes exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace
{
    return [ParsingRule type:resultingType options:0 minimumLength:0 minimumLengthAtInput:0 previousTypes:nil  exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:length allowedWhiteSpace:allowedWhiteSpace onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
        exactMatches:(NSArray<NSString*>*)exactMatches
{
    return [ParsingRule type:resultingType options:0 minimumLength:0 minimumLengthAtInput:0 previousTypes:nil exactMatches:exactMatches beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
        exactMatches:(NSArray<NSString*>*)exactMatches
   allowedWhitespace:(NSInteger)allowedWhitespace
{
    return [ParsingRule type:resultingType options:0 minimumLength:0 minimumLengthAtInput:0 previousTypes:nil exactMatches:exactMatches beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:allowedWhitespace onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber *> *)previousTypes
{
    return [ParsingRule type:resultingType options:options minimumLength:minimumLength minimumLengthAtInput:minimumLengthAtInput previousTypes:previousTypes exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes
          beginsWith:(NSArray<NSString *> *)beginsWith
            endsWith:(NSArray<NSString *> *)endsWith
 requiredAfterPrefix:(NSArray<NSString *> *)requiredAfterPrefix
excludedAfterPrefix:(NSArray<NSString *> *)excludedAfterPrefix
{
    return [ParsingRule type:resultingType options:options minimumLength:0 minimumLengthAtInput:0 previousTypes:previousTypes exactMatches:nil beginsWith:beginsWith endsWith:endsWith requiredAfterPrefix:requiredAfterPrefix excludedAfterPrefix:excludedAfterPrefix length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes
          beginsWith:(NSArray<NSString *> *)beginsWith
            endsWith:(NSArray<NSString *> *)endsWith
{
    return [ParsingRule type:resultingType options:options minimumLength:0 minimumLengthAtInput:0 previousTypes:previousTypes exactMatches:nil beginsWith:beginsWith endsWith:endsWith requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:0];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
          beginsWith:(NSArray<NSString *> *)beginsWith
       allowedSymbol:(unichar)allowedSymbol
{
    return [ParsingRule type:resultingType options:options minimumLength:0 minimumLengthAtInput:0 previousTypes:nil exactMatches:nil beginsWith:beginsWith endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:allowedSymbol];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       allowedSymbol:(unichar)allowedSymbol
{
    return [ParsingRule type:resultingType options:options minimumLength:minimumLength minimumLengthAtInput:minimumLengthAtInput previousTypes:nil exactMatches:nil beginsWith:nil endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil length:0 allowedWhiteSpace:0 onlyAllowedSymbol:allowedSymbol];
}

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber*>* _Nullable)previousTypes
        exactMatches:(NSArray<NSString*>* _Nullable)exactMatches
          beginsWith:(NSArray<NSString*>* _Nullable)beginsWith
            endsWith:(NSArray<NSString*>* _Nullable)endsWith
 requiredAfterPrefix:(NSArray<NSString*>* _Nullable)requiredAfterPrefix
 excludedAfterPrefix:(NSArray<NSString*>* _Nullable)excludedAfterPrefix
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace
   onlyAllowedSymbol:(unichar)allowedSymbol
{
    ParsingRule *rule = [[ParsingRule alloc] init];
    rule.resultingType = resultingType;
    rule.options = options;
    
    rule.minimumLength = minimumLength;
    rule.minimumLengthAtInput = minimumLengthAtInput;
    
    rule.exactMatches = exactMatches;
    rule.beginsWith = beginsWith ?: @[];
    rule.endsWith = endsWith ?: @[];
    rule.requiredAfterPrefix = requiredAfterPrefix ?: @[];
    rule.excludedAfterPrefix = excludedAfterPrefix ?: @[];
    rule.length = length;
    rule.allowedWhiteSpace = allowedWhiteSpace;
        
    rule.previousIsEmpty = mask_contains(options, PreviousIsEmpty);
    rule.allCapsUntilParentheses = mask_contains(options, AllCapsUntilParentheses);
    rule.allowsLeadingWhitespace = mask_contains(options, AllowsLeadingWhitespace);
    rule.nextIsEmpty = mask_contains(options, NextIsEmpty);
    rule.titlePage = mask_contains(options, BelongsToTitlePage);
    
    rule.allowedSymbol = allowedSymbol;
    
    NSMutableIndexSet *pTypes = NSMutableIndexSet.new;
    for (NSNumber *typeNumber in previousTypes) {
        [pTypes addIndex:[typeNumber unsignedIntegerValue]];
    }
    rule.previousTypes = [pTypes copy];
    
    return rule;
}

- (BOOL)validate:(Line*)line previousLine:(Line*)previousLine nextLine:(Line*)nextLine delegate:(id<ContinuousFountainParserDelegate>)delegate
{
    bool previousIsEmpty = previousLine.effectivelyEmpty || previousLine == nil;
    bool nextIsEmpty = (nextLine.type == empty);
   
    // Check length first
    bool isLongEnough = false;
    if (line.length >= self.minimumLength || (delegate.currentLine == line && line.length >= self.minimumLengthAtInput)) {
        isLongEnough = true;
    }
    
    // Apply all basic rules. Any of these should not fail.
    if ((!isLongEnough) ||                                                                          // Min length requirement failed
        (self.length > 0 && line.length > self.length) ||                                           // Max length requirement
        (self.previousIsEmpty && !previousIsEmpty) ||                                               // Previous isn't empty
        (self.nextIsEmpty && !nextIsEmpty) ||                                                       // Next isn't empty
        (mask_contains(self.options, PreviousIsNotEmpty) && previousLine.length == 0) ||            // Previous should NOT be empty, but isn't
        
        (self.allCapsUntilParentheses && !line.string.onlyUppercaseUntilParenthesis) ||             // Caps rules not fulfilled
        (line.string.containsOnlyWhitespace && line.length > self.allowedWhiteSpace && line.length < 2)  ||            // Wrong amount of whitespace 

        (mask_contains(self.options, RequiresTwoEmptyLines) && line.length == 0 && !nextIsEmpty)
        )
    {
        return false;
    }
    
    // First find the exact matches
    if (self.exactMatches.count > 0) {
        bool match = false;
        for (NSString* exactMatch in self.exactMatches) {
            if ([line.string isEqualToString:exactMatch]) match = true;
        }
        if (!match) return false;
    }
    
    // Catch special title page conditions
    if (self.titlePage) {
        // This can't be a title page element
        if ((previousLine == nil && ![line.string containsString:@":"]) ||
            (previousLine != nil && !previousLine.isTitlePage) ||
            (previousLine.isTitlePage && line.length == 0)) {
            return false;
        } else if (previousLine != nil && previousLine.isTitlePage && ![line.string containsString:@":"] && line.trimmed.length > 0) {
            // This IS a title element, and for nested lines, we need to be a little more allowing
            if (previousLine.type == self.resultingType) return true;
        }
    }
    
    // Perform more tests.
    if (
        // Check required previous type
        (self.previousTypes.count > 0 && ![self.previousTypes containsIndex:previousLine.type]) ||
        // Check required prefix
        (self.beginsWith.count > 0 && ![self matchesPrefix:line]) ||
        // Check required suffix
        (self.endsWith.count > 0 && ![self matchesSuffix:line]) ||
        // Contains only the allowed symbol
        (self.allowedSymbol > 0 && ![self containsOnlyAllowedSymbol:line])
    ) {
        // Nothing passed
        return false;
    }
        
    // Hooray, we've passed all tests!
    return true;
    
}

- (bool)matchesPrefix:(Line*)line
{
    NSInteger idx = (self.allowsLeadingWhitespace) ? line.string.indexOfFirstNonWhiteSpaceCharacter : 0;
    if (idx == NSNotFound) idx = 0;
    
    NSString* string = [line.string substringFromIndex:idx].lowercaseString;
    
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

- (bool)containsOnlyAllowedSymbol:(Line*)line
{
    NSString* string = (self.allowsLeadingWhitespace) ? line.string.trim : line.string.copy;
    
    for (NSInteger i=0;i<string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if (c != _allowedSymbol) return false;
    }
    
    return true;
}

@end
