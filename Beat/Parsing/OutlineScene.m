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

+ (OutlineScene*)withLine:(Line*)line {
	return [[OutlineScene alloc] initWithLine:line];
}
- (id)initWithLine:(Line*)line
{
	if ((self = [super init]) == nil) { return nil; }
	self.line = line;
	
	return self;
}
- (NSRange)range {
	return NSMakeRange(self.position, self.length);
}
- (NSString*)stringForDisplay {
	return self.line.stringForDisplay;
}
-(NSInteger)timeLength {
	// Welllll... this is a silly implementation, but let's do it.
	// We'll measure scene length purely by the character length, but let's substract the scene heading length
	NSInteger length = self.length - self.line.string.length + 40;
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
		@"sectionDepth": @(self.sectionDepth),

		@"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
		@"sceneStart": @(self.position),
		@"sceneLength": @(self.length),
		@"omitted": @(self.omitted),
		@"line": self.line.forSerialization
	};
}

// Forward these properties from line
-(LineType)type {
	return self.line.type;
}
-(NSUInteger)position {
	return self.line.position;
}
-(NSArray*)storylines {
	return self.line.storylines;
}

-(bool)omitted {return self.line.omitted; }
// Legacy compatibility
-(bool)omited {	return self.omitted; }

-(NSString*)color {
	return self.line.color;
}

// Backwards compatibility
-(NSUInteger)sceneStart { return self.position; }
-(NSUInteger)sceneLength { return self.length; }

@synthesize omited;

@end
/*
 
 This place is not a place of honor.
 No highly esteemed deed is commemorated here.
 Nothing valued is here.
 
 What is here was dangerous and repulsive to us.
 This message is a warning about danger.
 
 The danger is still present, in your time, as it was in ours.
 The danger is to the body, and it can kill.

 The form of the danger is an emanation of energy.

 The danger is unleashed only if you substantially disturb this place physically.
 This place is best shunned and left uninhabited.
 
 */
