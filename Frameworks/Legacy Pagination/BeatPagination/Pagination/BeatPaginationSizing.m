//
//  BeatPaginationSizing.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 24.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This experimental class provides default pagination sizes,
 and also reads a specific pagination block from custom CSS.
 
 pagination {
	action-a4: 12;
	action-us-letter: 13;
 }
 
 Usage: BeatPaginationSizing *sizing = [BeatPaginationSizing readStyle:cssContents];
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatPaginationSizing.h"

@implementation BeatPaginationSizing

-(instancetype)init {
	self = [super init];
	
	[self defaults];
	
	return self;
}

-(void)defaults {
	_actionA4 = 59;
	_actionUS = 61;
	_character = 38;
	_parenthetical = 28;
	_dialogue = 35;
	
	_dualDialogueA4 = 27;
	_dualDialogueUS = 28;
	
	_dualDialogueCharacterA4 = 20;
	_dualDialogueCharacterUS = 21;
	
	_dualDialogueParentheticalA4 = 25;
	_dualDialogueParentheticalUS = 26;
}

- (void)setWidth:(NSString*)key as:(NSInteger)value {
	// Keys to map to faux-CSS values
	static NSDictionary *keys;
	if (keys == nil) {
		keys = @{
			@"action-a4": @"actionA4",
			@"action-us-letter": @"actionUS",
			@"character": @"character",
			@"dialogue": @"dialogue",
			
			@"dual-dialogue-a4": @"dualDialogueA4",
			@"dual-dialogue-us-letter": @"dualDialogueUS",
			
			@"dual-dialogue-character-a4": @"dualDialogueCharacterA4",
			@"dual-dialogue-character-us-letter": @"dualDialogueCharacterUS",
			
			@"dual-dialogue-parenthetical-a4": @"dualDialogueParentheticalA4",
			@"dual-dialogue-parenthetical-us-letter": @"dualDialogueParentheticalUS",
		};
	}
	
	NSString *actualKey = keys[key];
	[self setValue:@(value) forKey:actualKey];
}

+ (BeatPaginationSizing*)readStyle:(NSString*)stylesheet {
	BeatPaginationSizing *sizing = BeatPaginationSizing.new;

	// Remove comments
	Rx* commentEx = [Rx rx:@"/\\*(.+?)\\*/" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators];
	stylesheet = [stylesheet replace:commentEx with:@""];
	
	// Regular expressions for styles
	Rx* styleEx = [Rx rx:@"(pagination).*{((.|\\n)*)}" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators];
	Rx* ruleEx = RX(@"(.*):(.*);\\n");
	
	
	NSArray* styleMatches = [stylesheet matchesWithDetails:styleEx];
	
	for (RxMatch *match in styleMatches) {
		NSString *ruleContent = [(RxMatchGroup*)match.groups[2] value];
		
		NSArray *ruleMatches = [ruleContent matchesWithDetails:ruleEx];
	
		for (RxMatch *ruleMatch in ruleMatches) {
			NSString *rule = [[(RxMatchGroup*)ruleMatch.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			NSString *value = [[(RxMatchGroup*)ruleMatch.groups[2] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			//[rules setValue:value forKey:rule];
			
			id writtenValue = value;
			if ([value isEqualToString:@"true"]) writtenValue = @(true);
			else if ([value isEqualToString:@"false"]) writtenValue = @(false);
			else {
				writtenValue = @([value integerValue]);
			}
			
			[sizing setValue:writtenValue forKey:rule];
		}
	}
	
	return sizing;
}


@end
