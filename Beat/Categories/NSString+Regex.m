//
//  +Regex.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "NSString+Regex.h"

@implementation NSString (Regex)

- (NSString *) stringByReplacingRegex:(NSString*)regex withString:(NSString*)replace {
	
	NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
	NSString *newString = [expression stringByReplacingMatchesInString:self options:0 range:NSMakeRange(0, [self length]) withTemplate:@""];
	return newString;
}

// We need to have enumerated options . . . . . . 
- (bool) matchesRegex:(NSString *)regex options:(NSMatchingOptions*)options inRange:(NSRange)range error:(NSError*)error {

	//NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
	NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];

	if ([test evaluateWithObject:self]) return YES; else return NO;

}
- (bool) matchesRegex:(NSString*)regex {
	return [self matchesRegex:regex options:nil inRange:NSMakeRange(0, [self length]) error:nil];
}

@end
