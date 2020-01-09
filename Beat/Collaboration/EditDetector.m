//
//  EditDetector.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16/11/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EditDetector.h"
#import "NSString+LongestCommonSubsequence.h"

@implementation EditDetector
/*

 Work in progress (very much)
 
 The idea is to get a automated collaboration workflow between two files at a cloud service. Meaning, no live editing, but the option to APPEND and WITHDRAW certain changes to the current document.
 
 As planned, the process would go as follows:
 - Get our current saved file contents (requires caching the string)
 - Get their saved file contents
 - Compare OUR saved and edited file, save changed indices
 - Compare THEIR saved and edited file to our SAVED file
 - Apply their changes to the saved file
 - Append our changes to the file
 
 There are many places where this could go wrong, but I'm planning to try it out, at least.
 
 */

- (NSArray *) detectEditsFrom:(NSString *)current to:(NSString *)edited {

	NSLog(@"lcs: %@", [current lcsDiff:edited]);
    NSLog(@"TEST");
	
	NSArray * diff = [current lcsDiff:edited];
	
	NSMutableString *result = [NSMutableString stringWithString:current];
	NSInteger currentIndex = 0;
	
	for (NSArray *item in diff) {
		NSUInteger index = [item[0] unsignedIntValue];
		NSString *weHave = (NSString*)item[1];
		NSString *theyHave = (NSString*)item[2];
		
		if ([weHave length] == 0) {
            [result insertString:theyHave atIndex:index + currentIndex];
			currentIndex += theyHave.length;
		}
        else if ([theyHave length] == 0) {
            [result replaceCharactersInRange:NSMakeRange(index + currentIndex, weHave.length) withString:@""];
            currentIndex -= weHave.length;
        }
        else {
            /*
            [result replaceCharactersInRange:NSMakeRange(index + currentIndex, theyHave.length) withString:theyHave];
            
            if (theyHave.length > weHave.length) {
                currentIndex += theyHave.length - weHave.length;
            } else {
                currentIndex += weHave.length - theyHave.length;
            }
             */
        }
	}
	NSLog(@"OLD: %@\nNEW: %@\nRESULT:%@", current, edited, result);
	
	return nil;
}

@end
