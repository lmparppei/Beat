//
//  ContinuousFountainParser+ParsingRules.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 8.3.2026.
//

#import "ContinuousFountainParser+ParsingRules.h"

@implementation ContinuousFountainParser (ParsingRules)

+ (NSArray<ParsingRule*>* _Nonnull)rules
{
    static NSArray<ParsingRule*>* rules = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rules = @[
            [ParsingRule type:empty exactMatches:@[@"", @" "] allowedWhitespace:1],
            [ParsingRule type:heading options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@".", @"．"] endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:@[@"."]],
            [ParsingRule type:shot options:0 previousTypes:nil beginsWith:@[@"!!", @"！！"] endsWith:nil],
            [ParsingRule type:action options:0 previousTypes:nil beginsWith:@[@"!", @"！"] endsWith:nil],
            [ParsingRule type:lyrics options:(AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@"~", @"～"] endsWith:nil],
            [ParsingRule type:dualDialogueCharacter options:(PreviousIsEmpty | AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@"@", @"＠"] endsWith:@[@"^"]],
            [ParsingRule type:character options:(PreviousIsEmpty | AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@"@", @"＠"] endsWith:nil],
            
            [ParsingRule type:pageBreak options:(AllowsLeadingWhitespace) minimumLength:3 minimumLengthAtInput:3 allowedSymbol:'='],
            
            [ParsingRule type:section options:0 previousTypes:nil beginsWith:@[@"#", @"＃"] endsWith:nil],
            [ParsingRule type:synopse options:0 previousTypes:nil beginsWith:@[@"="] endsWith:nil],
            
            [ParsingRule type:heading options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@"int", @"ext", @"i/e", @"i./e", @"e/i", @"e./i"] endsWith:nil requiredAfterPrefix:@[@" ", @"."] excludedAfterPrefix:nil],
            [ParsingRule type:centered options:(AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@">"] endsWith:@[@"<"]],
            [ParsingRule type:transitionLine options:0 previousTypes:nil beginsWith:@[@">"] endsWith:nil],
            [ParsingRule type:transitionLine options:(PreviousIsEmpty | AllCapsUntilParentheses) previousTypes:nil beginsWith:nil endsWith:@[@"TO:"]],
            
            // Dual dialogue
            [ParsingRule type:dualDialogueCharacter options:(PreviousIsEmpty | AllCapsUntilParentheses | AllowsLeadingWhitespace) previousTypes:nil beginsWith:nil endsWith:@[@"^"] requiredAfterPrefix:nil excludedAfterPrefix:nil],
            [ParsingRule type:dualDialogueParenthetical options:(AllowsLeadingWhitespace | PreviousIsNotEmpty)  previousTypes:@[@(dualDialogueCharacter), @(dualDialogue)] beginsWith:@[@"("] endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil],
            [ParsingRule type:dualDialogue options:(AllowsLeadingWhitespace | PreviousIsNotEmpty) minimumLength:1 previousTypes:@[@(dualDialogueCharacter), @(dualDialogue), @(dualDialogueParenthetical)]],
            
            // Dialogue
            [ParsingRule type:character options:(PreviousIsEmpty | AllCapsUntilParentheses | AllowsLeadingWhitespace) minimumLength:2 minimumLengthAtInput:3 previousTypes:nil],
            [ParsingRule type:parenthetical options:(AllowsLeadingWhitespace | PreviousIsNotEmpty) previousTypes:@[@(character), @(dialogue), @(parenthetical)] beginsWith:@[@"("] endsWith:nil],
            [ParsingRule type:dialogue options:(AllowsLeadingWhitespace | RequiresTwoEmptyLines | PreviousIsNotEmpty) minimumLength:0 previousTypes:@[@(character), @(dialogue), @(parenthetical)]],
            
            [ParsingRule type:titlePageTitle options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"title:"] endsWith:nil ],
            [ParsingRule type:titlePageCredit options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"credit:"] endsWith:nil],
            [ParsingRule type:titlePageAuthor options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"author:", @"authors:"] endsWith:nil],
            [ParsingRule type:titlePageSource options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"source:"] endsWith:nil],
            [ParsingRule type:titlePageContact options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"contact:"] endsWith:nil],
            [ParsingRule type:titlePageDraftDate options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"draft date:"] endsWith:nil],
            [ParsingRule type:titlePageUnknown options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:nil endsWith:nil]
        ];
    });
    
    return rules;
}

@end
