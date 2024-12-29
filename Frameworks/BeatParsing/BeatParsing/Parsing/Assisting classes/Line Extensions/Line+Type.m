//
//  Line+Type.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import "Line+Type.h"

@implementation Line (Type)

/// Returns internal type name, which is not the human-readable version.
- (NSString*)typeName
{
    return [Line typeName:self.type];
}

/// Retuns current line type as human-readable string
- (NSString*)typeAsString
{
    return [Line typeAsString:self.type];
}

/// For future generations. Not used anywhere now.
+ (NSDictionary<NSNumber*, NSString*>*)forcingSymbols
{
    static NSDictionary* forcingSymbols;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        forcingSymbols = @{
            @(pageBreak): @"===",
            @(heading): @".",
            @(shot): @"!!",
            @(action): @"!",
            @(character): @"@",
            @(lyrics): @"~",
            @(synopse): @"=",
            @(transitionLine): @">",
        };
    });
    
    return forcingSymbols;
}

/// Used by plugin API to create constants for matching line types to enumerated integer values
+ (NSDictionary*)typeDictionary
{
    NSMutableDictionary *types = NSMutableDictionary.dictionary;
    
    NSInteger max = typeCount;
    for (NSInteger i = 0; i < max; i++) {
        LineType type = i;
        NSString *typeName = [Line typeName:type];
        
        [types setValue:@(i) forKey:typeName];
    }
    
    return types;
}

+ (NSString*)typeName:(LineType)type {
    switch (type) {
        case empty:
            return @"empty";
        case section:
            return @"section";
        case synopse:
            return @"synopsis";
        case titlePageTitle:
            return @"titlePageTitle";
        case titlePageAuthor:
            return @"titlePageAuthor";
        case titlePageCredit:
            return @"titlePageCredit";
        case titlePageSource:
            return @"titlePageSource";
        case titlePageContact:
            return @"titlePageContact";
        case titlePageDraftDate:
            return @"titlePageDraftDate";
        case titlePageUnknown:
            return @"titlePageUnknown";
        case heading:
            return @"heading";
        case action:
            return @"action";
        case character:
            return @"character";
        case parenthetical:
            return @"parenthetical";
        case dialogue:
            return @"dialogue";
        case dualDialogueCharacter:
            return @"dualDialogueCharacter";
        case dualDialogueParenthetical:
            return @"dualDialogueParenthetical";
        case dualDialogue:
            return @"dualDialogue";
        case transitionLine:
            return @"transition";
        case lyrics:
            return @"lyrics";
        case pageBreak:
            return @"pageBreak";
        case centered:
            return @"centered";
        case more:
            return @"more";
        case dualDialogueMore:
            return @"dualDialogueMore";
        case shot:
            return @"shot";
        case typeCount:
            return @"";
    }
}

/// Returns line type as human-readable string
+ (NSString*)typeAsString:(LineType)type {
    switch (type) {
        case empty:
            return @"Empty";
        case section:
            return @"Section";
        case synopse:
            return @"Synopse";
        case titlePageTitle:
            return @"Title Page Title";
        case titlePageAuthor:
            return @"Title Page Author";
        case titlePageCredit:
            return @"Title Page Credit";
        case titlePageSource:
            return @"Title Page Source";
        case titlePageContact:
            return @"Title Page Contact";
        case titlePageDraftDate:
            return @"Title Page Draft Date";
        case titlePageUnknown:
            return @"Title Page Unknown";
        case heading:
            return @"Heading";
        case action:
            return @"Action";
        case character:
            return @"Character";
        case parenthetical:
            return @"Parenthetical";
        case dialogue:
            return @"Dialogue";
        case dualDialogueCharacter:
            return @"DD Character";
        case dualDialogueParenthetical:
            return @"DD Parenthetical";
        case dualDialogue:
            return @"DD Dialogue";
        case transitionLine:
            return @"Transition";
        case lyrics:
            return @"Lyrics";
        case pageBreak:
            return @"Page Break";
        case centered:
            return @"Centered";
        case shot:
            return @"Shot";
        case more:
            return @"More";
        case dualDialogueMore:
            return @"DD More";
        case typeCount:
            return @"";
    }
}

/// Returns line type for string
+ (LineType)typeFromName:(NSString *)name
{
    if ([name isEqualToString:@"empty"]) {
        return empty;
    } else if ([name isEqualToString:@"section"]) {
        return section;
    } else if ([name isEqualToString:@"synopsis"]) {
        return synopse;
    } else if ([name isEqualToString:@"titlePageTitle"]) {
        return titlePageTitle;
    } else if ([name isEqualToString:@"titlePageAuthor"]) {
        return titlePageAuthor;
    } else if ([name isEqualToString:@"titlePageCredit"]) {
        return titlePageCredit;
    } else if ([name isEqualToString:@"titlePageSource"]) {
        return titlePageSource;
    } else if ([name isEqualToString:@"titlePageContact"]) {
        return titlePageContact;
    } else if ([name isEqualToString:@"titlePageDraftDate"]) {
        return titlePageDraftDate;
    } else if ([name isEqualToString:@"titlePageUnknown"]) {
        return titlePageUnknown;
    } else if ([name isEqualToString:@"heading"]) {
        return heading;
    } else if ([name isEqualToString:@"action"]) {
        return action;
    } else if ([name isEqualToString:@"character"]) {
        return character;
    } else if ([name isEqualToString:@"parenthetical"]) {
        return parenthetical;
    } else if ([name isEqualToString:@"dialogue"]) {
        return dialogue;
    } else if ([name isEqualToString:@"dualDialogueCharacter"]) {
        return dualDialogueCharacter;
    } else if ([name isEqualToString:@"dualDialogueParenthetical"]) {
        return dualDialogueParenthetical;
    } else if ([name isEqualToString:@"dualDialogue"]) {
        return dualDialogue;
    } else if ([name isEqualToString:@"transition"]) {
        return transitionLine;
    } else if ([name isEqualToString:@"lyrics"]) {
        return lyrics;
    } else if ([name isEqualToString:@"pageBreak"]) {
        return pageBreak;
    } else if ([name isEqualToString:@"centered"]) {
        return centered;
    } else if ([name isEqualToString:@"shot"]) {
        return shot;
    } else if ([name isEqualToString:@"more"]) {
        return more;
    } else if ([name isEqualToString:@"dualDialogueMore"]) {
        return dualDialogueMore;
    } else {
        return typeCount;
    }
}

@end
