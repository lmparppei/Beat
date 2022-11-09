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
@end
