//
//  NSString+Regex.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is an Objective-C class which aims to replace RegexKitLite.h one sweet day.	
 
 */

#import <Foundation/Foundation.h>


@interface NSString (Regex)
- (NSString*) stringByReplacingRegex:(NSString*)regex withString:(NSString*)replace;
- (bool) matchesRegex:(NSString *)regex options:(NSMatchingOptions*)options inRange:(NSRange)range error:(NSError*)error;
- (bool) matchesRegex:(NSString*)regex;
@end

