//
//  BeatFont.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 4.6.2023.
//

#import "BeatFont.h"


@implementation BeatFont

- (instancetype)initWithFontNames:(NSString *)plainFontName
                             bold:(NSString *)boldFontName
                           italic:(NSString *)italicFontName
                       boldItalic:(NSString *)boldItalicFontName
                            emoji:(NSString *)emojiFontName {
    self = [super init];
    
    if (self) {
        CGFloat fontSize = 12.0;
        
        _plain = [BXFont fontWithName:plainFontName size:fontSize];
        _bold = [BXFont fontWithName:boldFontName size:fontSize];
        _italic = [BXFont fontWithName:italicFontName size:fontSize];
        _boldItalic = [BXFont fontWithName:boldItalicFontName size:fontSize];
        _emojiFont = [BXFont fontWithName:emojiFontName size:fontSize];
    }
    return self;
}

@end
