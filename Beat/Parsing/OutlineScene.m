//
//  OutlineScene.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Ideas for redesign at some point:
 Using delegation, we could calculate the length only when required.
 Honstely, it's pretty unclear if this would actually give a performance boost or loss,
 but it shouldn't be *that* bad. In some cases, like when typing on a heading line,
 the new method would probably be a lot more efficient.
 
 */

#import <Foundation/Foundation.h>
#import "OutlineScene.h"
#import "ContinuousFountainParser.h"

@implementation OutlineScene

+ (OutlineScene*)withLine:(Line*)line delegate:(id)delegate {
	return [[OutlineScene alloc] initWithLine:line delegate:delegate];
}

+ (OutlineScene*)withLine:(Line*)line {
	return [[OutlineScene alloc] initWithLine:line];
}
- (id)initWithLine:(Line*)line {
	return [self initWithLine:line delegate:nil];
}
- (id)initWithLine:(Line*)line delegate:(id)delegate
{
	if ((self = [super init]) == nil) { return nil; }

	self.line = line;
	self.delegate = delegate;
	
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

#pragma mark - JSON serialization

// Plugin compatibility
- (NSDictionary*)forSerialization {
	return @{
		// String values have to be guarded so we don't try to put nil into NSDictionary
		@"string": (self.string.length) ? self.string.copy : @"",
		@"typeAsString": (self.line.typeAsString) ? self.line.typeAsString : @"",
		@"stringForDisplay": (self.stringForDisplay.length) ? self.stringForDisplay : @"",
		@"storylines": (self.storylines) ? self.storylines.copy : @[],
		@"sceneNumber": (self.sceneNumber) ? self.sceneNumber.copy : @"",
		@"color": (self.color) ? self.color.copy : @"",
		@"sectionDepth": @(self.sectionDepth),
		@"markerColors": (self.markerColors.count) ? self.markerColors.allObjects.copy : @[],
		@"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
		@"sceneStart": @(self.position),
		@"sceneLength": @(self.length),
		@"omitted": @(self.omitted),
		@"line": self.line.forSerialization
	};
}

#pragma mark - Forwarded properties

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

#pragma mark - Generated properties

-(NSUInteger)length {
	if (!_delegate) return _length;
	if (self.type == synopse) return self.line.range.length;
	
	NSArray *lines = self.delegate.lines;
	NSInteger index = [lines indexOfObject:self.line];
	
	NSInteger length = -1;
	
	for (NSInteger i = index + 1; i < lines.count; i++) {
		// To avoid any race conditions, let's break this loop if the lines array was changed
		if (!lines[i] || i >= lines.count) break;
		
		Line *line = lines[i];
		if ((line.type == heading || line.type == section) && line != self.line) {
			return line.position - self.position;
		}
	}
	
	if (length == -1) {
		return [(Line*)lines.lastObject position] - self.position;
	}
	
	return length;
}

-(NSArray*)characters {
	NSArray *lines = self.delegate.lines;
	NSInteger index = [lines indexOfObject:self.line];
	
	NSMutableSet *names = NSMutableSet.set;
	
	for (NSInteger i = index + 1; i < lines.count; i++) {
		Line *line = lines[i];
		if (line.isOutlineElement && line.type != synopse) break;
		else if (line.type == character || line.type == dualDialogueCharacter) {
			NSString *characterName = line.characterName;
			if (characterName.length) [names addObject:line.characterName];
		}
	}
	
	return names.allObjects;
}

-(NSUInteger)omissionStartsAt {
	if (!self.omitted) return -1;
	
	NSArray *lines = self.delegate.lines;
	NSInteger idx = [lines indexOfObject:self.line];
	
	// Find out where the omission starts
	for (NSInteger s = idx; s >= 0; s--) {
		Line *prevLine = lines[s];
		NSInteger omitLoc = [prevLine.string rangeOfString:@"/*"].location;
		if (omitLoc != NSNotFound && prevLine.omitOut) {
			return prevLine.position + omitLoc;
		}
	}
	
	return -1;
}

-(NSUInteger)omissionEndsAt {
	if (!self.omitted) return -1;
	
	NSArray *lines = self.delegate.lines;
	NSInteger idx = [lines indexOfObject:self.line];
	
	// Find out where the omission ends
	for (NSInteger s = idx + 1; s < lines.count; s++) {
		Line *nextLine = lines[s];
		NSInteger omitEndLoc = [nextLine.string rangeOfString:@"*/"].location;
		
		if (omitEndLoc != NSNotFound && nextLine.omitIn) {
			return nextLine.position + omitEndLoc;
			break;
		}
	}
	
	return -1;
}



#pragma mark - Synthesized properties

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
