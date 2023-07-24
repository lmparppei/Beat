//
//  NSString+VersionNumber.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "NSString+VersionNumber.h"

@implementation NSString (VersionNumber)
- (NSString *)shortenedVersionNumberString {
	static NSString *const unnecessaryVersionSuffix = @".0";
	NSString *shortenedVersionNumber = self;

	while ([shortenedVersionNumber hasSuffix:unnecessaryVersionSuffix]) {
		shortenedVersionNumber = [shortenedVersionNumber substringToIndex:shortenedVersionNumber.length - unnecessaryVersionSuffix.length];
	}

	return shortenedVersionNumber;
}

- (bool)isNewerVersionThan:(NSString*)old {
	if ([self isEqualToString:old]) return YES;
		
	NSArray* newComp = [self componentsSeparatedByString:@"."];
	NSArray* oldComp = [old componentsSeparatedByString:@"."];

	NSInteger pos = 0;

	while (newComp.count > pos || oldComp.count > pos) {
		NSInteger v1 = newComp.count > pos ? [[newComp objectAtIndex:pos] integerValue] : 0;
		NSInteger v2 = oldComp.count > pos ? [[oldComp objectAtIndex:pos] integerValue] : 0;
		
		if (v1 < v2) return NO;
		else if (v1 > v2) return YES;
		
		pos++;
	}
	
	return NO;
}
@end
