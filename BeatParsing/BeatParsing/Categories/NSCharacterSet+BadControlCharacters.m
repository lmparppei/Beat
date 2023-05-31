//
//  NSCharacterSet+BadControlCharacters.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.5.2023.
//

#import "NSCharacterSet+BadControlCharacters.h"

@implementation NSCharacterSet (BadControlCharacters)

+ (NSCharacterSet*)badControlCharacters {
    static NSCharacterSet* badCharacters;
    if (badCharacters == nil) {
        NSMutableCharacterSet* c = NSCharacterSet.controlCharacterSet.mutableCopy;
        [c removeCharactersInString:@"\n\t"];
        badCharacters = c;
    }
    
    return badCharacters;
}

@end
