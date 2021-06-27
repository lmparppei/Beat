//
//  OutlineScene.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OutlineScene.h"
#import "ContinuousFountainParser.h"

@implementation OutlineScene

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
	
	return self;
}
- (NSRange)range {
	return NSMakeRange(self.sceneStart, self.sceneLength);
}
- (NSString*)stringForDisplay {
	return self.line.stringForDisplay;
}
-(NSInteger)timeLength {
	// Welllll... this is a silly implementation, but let's do it.
	// We'll measure scene length purely by the character length, but let's substract the scene heading length
	NSInteger length = self.sceneLength - self.line.string.length + 40;
	if (length < 0) length = 40;
	
	return length;
}
- (NSString*)typeAsString {
	return self.line.typeAsString;
}

// Plugin compatibility
- (NSDictionary*)forSerialization {
	return @{
		// String values have to be guarded so we don't try to put nil into NSDictionary
		@"string": (self.string.length) ? self.string : @"",
		@"typeAsString": (self.line.typeAsString) ? self.line.typeAsString : @"",
		@"stringForDisplay": (self.stringForDisplay.length) ? self.stringForDisplay : @"",
		@"storylines": (self.storylines) ? self.storylines : @[],
		@"sceneNumber": (self.sceneNumber) ? self.sceneNumber : @"",
		@"color": (self.color) ? self.color : @"",

		@"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
		@"sceneStart": @(self.sceneStart),
		@"sceneLength": @(self.sceneLength),
		@"omitted": @(self.omitted),
		@"line": self.line.forSerialization
	};
}

// Legacy compatibility
-(bool)omited {	return self.omitted; }

@synthesize omited;

@end
