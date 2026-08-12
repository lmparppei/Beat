//
//  BeatNoteData.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 1.4.2023.
//
/**
 
 # Note Object
 
 Note parsing is done by the parser. It creates `BeatNoteData` objects for each `[[note]]` on a line.
 Each note knows its own `range`, `type` (whether it's a normal note, color, marker, or beat), `color` (if applicable) and if the note is part of a `multiline` note block.
 
 */

#import "BeatNoteData.h"
#import <BeatParsing/ContinuousFountainParser.h>

@implementation BeatNoteData

+ (BeatNoteData*)withNote:(NSString *)text range:(NSRange)range
{
    NSString* content = text;
    NSString* color = @"";
    
    NoteType type = NoteTypeNormal;
    NSString* lowercaseText = content.lowercaseString;
    
    if ([lowercaseText rangeOfString:@"marker"].location == 0) {
        // Check if this note is a marker
        type = NoteTypeMarker;
    } else if ([ContinuousFountainParser.colors containsObject:lowercaseText] || [lowercaseText rangeOfString:@"color"].location == 0) {
        // This note only contains a color
        type = NoteTypeColor;
    } else if ([lowercaseText rangeOfString:@"beat"].location == 0 || [lowercaseText rangeOfString:@"storyline"].location == 0) {
        type = NoteTypeBeat;
    } else if ([lowercaseText rangeOfString:@"page "].location == 0) {
        type = NoteTypePageNumber;
    } else if ([lowercaseText containsString:@":"]) {
        // Check if this note has a color assigned to it, ie. [[red: Hello World]]
        NSInteger i = [lowercaseText rangeOfString:@":"].location;
        NSString* c = [lowercaseText substringToIndex:i];
        if (c.length > 0 && ([c characterAtIndex:0] == '#' || [ContinuousFountainParser.colors containsObject:c])) {
            color = c;
            content = [text substringFromIndex:i+1];
        }
    }
        
    return [BeatNoteData.alloc initWithContent:content color:color range:range type:type];
}

-(instancetype)initWithContent:(NSString*)content color:(NSString*)color range:(NSRange)range type:(NoteType)type
{
    self = [super init];
    if (self) {
        _content = content;
        _color = color;
        _range = range;
        _type = type;
    }
    
    return self;
}

/// Returns JSON representation
-(NSDictionary *)json
{
    return @{
        @"content": (_content != nil) ? _content : @"",
        @"color": (_color != nil) ? _color : @"",
        @"range": @{ @"location": @(_range.location), @"length": @(_range.length) },
        @"type": [self typeAsString]
    };
}

-(NSString*)typeAsString
{
    switch (self.type) {
        case NoteTypeNormal:
            return @"note";
        case NoteTypeColor:
            return @"color";
        case NoteTypeMarker:
            return @"marker";
        case NoteTypeBeat:
            return @"beat";
        case NoteTypePageNumber:
            return @"page";
        case NoteTypeTodo:
            return @"todo";
        default:
            return @"";
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Note: %@ (%lu, %lu)", self.content, self.range.location, self.range.length];
}

@end
/**
 
 writing this on a train
 the same landscapes
 every time but
 i don't seem to memorize them
 just a house here and there
 a pier
 a bridge
 that's all
 
 i've travelled these tracks
 200 kilometers
 over and over again
 but i can't remember a single trip
 
 and from the landscape
 of my past
 all i can remember are
 the worst moments
 i've let them define me
 all i can remember
 are the darkest hours
 when i wasn't
 myself
 whatever that means
 am i that
 am i those moments
 can i be forgiven
 forgiven by me
 by others
 by anyone
 
 on the train again
 meaningless seats
 meaningless landscapes
 meaningless coffee
 and i won't remember this
 trip
 either
 i'm so sorry
 forgive me,
 train
 
 */
