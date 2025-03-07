//
//  ContinuousFountainParser+Omissions.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 15.7.2024.
//

#import "ContinuousFountainParser+Omissions.h"

@implementation ContinuousFountainParser (Omissions)

/// Returns the actual character index of omission open. Returns `NSNotFound` if the omission is NOT JUST FOR THIS SCENE.
- (NSInteger)findSceneOmissionStartFor:(OutlineScene*)scene
{
    NSInteger lineIndex = [self lineIndexAtPosition:scene.position];
    for (NSInteger i=lineIndex-1; i>=0; i--) {
        Line* line = self.lines[i];
        if (line.length == 0 || line.type == empty) continue;
        
        // Find out where omission begins. Let's trim it first and see if it's the only thing on this line.
        NSInteger p = [line.string.trim rangeOfString:@"/*"].location;
        // If there's no omission on this line, we'll leave it in the other scene.
        if (p == NSNotFound || p > 0) return NSNotFound;
        else return line.position + [line.string rangeOfString:@"/*"].location;
    }
    
    return NSNotFound;
}

- (NSInteger)findOmissionStartFrom:(NSInteger)position
{
    NSInteger lineIndex = [self lineIndexAtPosition:position];
    for (NSInteger i=lineIndex-1; i>=0; i--) {
        Line* line = self.lines[i];
        NSRange omission = [line.string rangeOfString:@"/*"];
        
        if (omission.location != NSNotFound) return line.position + omission.location;
    }
    
    return NSNotFound;
}

@end
