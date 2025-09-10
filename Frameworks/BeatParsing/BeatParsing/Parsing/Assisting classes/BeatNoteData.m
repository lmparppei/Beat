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
    } else if ([BeatNoteData.colors containsObject:lowercaseText] || [lowercaseText rangeOfString:@"color"].location == 0) {
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
        if (c.length > 0 && ([c characterAtIndex:0] == '#' || [BeatNoteData.colors containsObject:c])) {
            color = c;
            content = [text substringFromIndex:i+1];
        }
    }
        
    return [BeatNoteData.alloc initWithContent:content color:color range:range type:type];
}

+ (NSArray<NSString*>*)colors
{
    static NSArray* colors;
    if (colors == nil) colors = @[@"red", @"blue", @"green", @"pink", @"magenta", @"gray", @"purple", @"cyan", @"teal", @"yellow", @"orange", @"brown"];
    return colors;
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
        default:
            return @"";
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Note: %@ (%lu, %lu)", self.content, self.range.location, self.range.length];
}

@end
