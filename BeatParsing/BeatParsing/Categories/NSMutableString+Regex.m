//
//  NSString+Regex.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/08/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSMutableString+Regex.h"

@implementation NSMutableString (Regex)

-(void) replaceByRegex: (NSString *) regex withString:(NSString *) replacement {
	NSRange range = NSMakeRange(0, [self length]);
	
	//replaceOccurrencesOfString:@"^" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, text.length)
	
	NSRegularExpression * expression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
	
	NSString * newString = [expression stringByReplacingMatchesInString:self options:0 range:range withTemplate:replacement];
	
	[self setString:newString];
}

@end
