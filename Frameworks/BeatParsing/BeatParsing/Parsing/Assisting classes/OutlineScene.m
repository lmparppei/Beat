//
//  OutlineScene.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatNoteData.h>
#import "OutlineScene.h"
#import <BeatParsing/Line+Type.h>

@implementation OutlineScene

+ (OutlineScene*)withLine:(Line*)line delegate:(id)delegate
{
	return [[OutlineScene alloc] initWithLine:line delegate:delegate];
}

+ (OutlineScene*)withLine:(Line*)line
{
	return [[OutlineScene alloc] initWithLine:line];
}

- (id)initWithLine:(Line*)line
{
	return [self initWithLine:line delegate:nil];
}

- (id)initWithLine:(Line*)line delegate:(id)delegate
{
	if ((self = [super init]) == nil) { return nil; }
	
	self.line = line;
	self.delegate = delegate;
	self.beats = NSMutableArray.new;
    self.synopsis = NSMutableArray.new;
    self.lines = NSMutableArray.new;
    
	return self;
}

/// Calculates the range for this scene
- (NSRange)range
{
	return NSMakeRange(self.position, self.length);
}

/// Returns a very unreliable "chronometric" length for the scene
-(NSInteger)timeLength
{
	// Welllll... this is a silly implementation, but let's do it.
	// We'll measure scene length purely by the character length, but let's substract the scene heading length
	NSInteger length = self.length - self.line.string.length + 40;
	if (length < 0) length = 40;
	
	return length;
}

#pragma mark - JSON serialization

/// Returns JSON data for scene properties (convenience method)
- (NSDictionary*)json
{
	return [self forSerialization];
}
/// Returns JSON data for scene properties
- (NSDictionary*)forSerialization
{
    @synchronized (self) {
        NSMutableArray <NSDictionary*>*synopsis = [NSMutableArray arrayWithCapacity:_synopsis.count];
        for (Line * s in _synopsis) [synopsis addObject:s.forSerialization];
        
        NSDictionary* json = @{
            // String values have to be guarded so we don't try to put nil into NSDictionary
            @"string": (self.string != nil) ? self.string.copy : @"",
            @"typeAsString": (self.line.typeAsString) ? self.line.typeAsString : @"",
            @"type": self.line.typeName,
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
            @"synopsis": synopsis,
            @"storybeats": (self.beats.count) ? [self serializedBeats] : @[],
            @"line": self.line.forSerialization,
            @"notes": [self notesAsJSON],
            @"uuid": self.line.uuidString
        };
        
        return json;
    }
}

- (NSArray*)serializedBeats
{
	NSMutableArray *beats = NSMutableArray.new;
	for (Storybeat *beat in self.beats) {
		[beats addObject:beat.forSerialization];
	}
	return beats;
}

- (NSArray*)notesAsJSON
{
    NSArray* noteData = self.notes;
    NSMutableArray* notes = NSMutableArray.new;
    for (BeatNoteData* note in noteData) {
        [notes addObject:note.json];
    }
    return notes;
}

#pragma mark - Section hierarchy

-(NSInteger)sectionDepth
{
    self.oldSectionDepth = self.line.sectionDepth;
    return _sectionDepth;
}

#pragma mark - Forwarded properties

- (LineType)type { return self.line.type; }

- (NSString*)stringForDisplay { return self.line.stringForDisplay; }
- (NSString*)string { return self.line.string; }
- (NSString*)typeAsString { return self.line.typeAsString; }

- (NSUInteger)position { return self.line.position; }

- (bool)omitted {return self.line.omitted; }
- (bool)omited { return self.omitted; } // Legacy compatibility

- (NSString*)color { return self.line.color; }

- (NSString*)sceneNumber { return self.line.sceneNumber; }
- (void)setSceneNumber:(NSString *)sceneNumber { self.line.sceneNumber = sceneNumber; }

// Plugin backwards compatibility
- (NSUInteger)sceneStart { return self.position; }
- (NSUInteger)sceneLength { return self.length; }

#pragma mark - Generated properties

-(NSUInteger)length
{
	if (_delegate == nil) return _length;
    
    @synchronized (self.delegate.lines) {
        NSArray <Line*> *lines = self.delegate.lines.copy;
        
        NSInteger index = [self.delegate indexOfLine:self.line];
        if (index == NSNotFound) return 0;
        
        NSInteger length = -1;
        
        for (NSInteger i = index + 1; i < lines.count; i++) {
            // To avoid any race conditions, let's break this loop if the lines array was changed
            if (!lines[i] || i >= lines.count) break;
            
            Line *line = lines[i];
            if ((line.type == heading || line.type == section) && line != self.line) {
                return line.position - self.position;
            }
        }
        
        // No length set - this is probably the last object in outline, so let's assume it takes up the rest of the document.
        if (length == -1) {
            return NSMaxRange(lines.lastObject.textRange) - self.position;
        }
        
        return length;
    }
}

/// Fetches the lines for this scene.
/// - note: The scene has to have a delegate set for this to work. In a normal situation, this should be the case, but if you are receiving an empty array or getting an error, check if there are issues with initialization.
-(NSArray<Line*>*)lines
{
    return [self.delegate linesForScene:self];
}

/// Returns an array of characters who have dialogue in this scene
-(NSArray*)characters
{
    NSArray *lines = self.lines;
	
	NSMutableSet *names = NSMutableSet.set;
	
	for (Line* line in lines) {
		if (line.isOutlineElement && line.type != synopse && line != self.line) break;
		else if (line.type == character || line.type == dualDialogueCharacter) {
			NSString *characterName = line.characterName;
			if (characterName.length) [names addObject:line.characterName];
		}
	}
	
	return names.allObjects;
}

/// An experimental method for finding where the omission covering this scene begins at.
-(NSUInteger)omissionStartsAt
{
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

/// An experimental method for finding where the omission covering this scene ends at.
-(NSUInteger)omissionEndsAt
{
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

/// Returns the storyline NAMES in this scene
- (NSArray<NSString*>*)storylines
{
    NSMutableArray* beats = self.beats.copy;
    NSMutableArray* storylines = NSMutableArray.new;
    
    for (Storybeat* beat in beats) {
        [storylines addObject:beat.storyline];
    }
    
    return storylines;
}


#pragma mark - Ownership

/// Convenience method for `.parent.children`
- (NSArray*)siblings
{
    return self.parent.children;
}


#pragma mark - Synthesized properties

@synthesize omited;


#pragma mark - Debugging

-(NSString *)description
{
    return [NSString stringWithFormat:@"Scene: %@ (pos %lu / len %lu)", self.string, self.position, self.length];
}


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
