//
//  BeatNoteData.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 1.4.2023.
//

#import "BeatNoteData.h"

@implementation BeatNoteData

+ (BeatNoteData*)withNote:(NSString *)text range:(NSRange)range
{
    NSString* content = text;
    NSString* color = @"";
    
    if ([text containsString:@":"]) {
        NSInteger i = [text rangeOfString:@":"].location;
        NSString* c = [text substringToIndex:i];
        if (c.length > 0 && ([c characterAtIndex:0] == '#' || [[BeatNoteData colors] containsObject:c])) {
            color = c;
            content = [text substringFromIndex:i+1];
        }
    }
    
    return [BeatNoteData.alloc initWithContent:content color:color range:range];
}

+ (NSArray<NSString*>*)colors
{
    static NSArray* colors;
    if (colors == nil) colors = @[@"red", @"blue", @"green", @"pink", @"magenta", @"gray", @"purple", @"cyan", @"teal", @"yellow", @"orange", @"brown"];
    return colors;
}


-(instancetype)initWithContent:(NSString*)content color:(NSString*)color range:(NSRange)range
{
    self = [super init];
    if (self) {
        _content = content;
        _color = color;
        _range = range;
    }
    
    return self;
}

@end
