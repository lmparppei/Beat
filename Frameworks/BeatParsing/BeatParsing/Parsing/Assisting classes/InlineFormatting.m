//
//  InlineFormatting.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 16.1.2026.
//

#import "InlineFormatting.h"


@implementation InlineFormatting

/// The inline markup ranges we will be parsing and formatting in the editor.
/// @note This doesn't contain note and omission, because they have their own parsing rules.
+ (NSArray<InlineFormatting*>*)rangesToFormat
{
    static NSArray* rangesToFormat;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        rangesToFormat = @[
            [InlineFormatting type:FormattingRangeBold delim:"**" delimLength:2],
            [InlineFormatting type:FormattingRangeItalic delim:"*" delimLength:1],
            [InlineFormatting type:FormattingRangeUnderlined delim:"_" delimLength:1],
            [InlineFormatting type:FormattingRangeMacro open:"{{" close:"}}" delimLength:2],
            [InlineFormatting type:FormattingRangeHighlight open:"+" close:"+" delimLength:1]
        ];
    });
    
    return rangesToFormat;
}



+ (NSDictionary<NSNumber*,InlineFormatting*>*)inlineFormats
{
    static NSArray* allFormats;
    static NSDictionary* formats;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        // NOTE: These are NOT used for parsing. They just help with applying inline formatting to attributed strings.
        allFormats = @[
            [InlineFormatting type:FormattingRangeBold delim:"**" delimLength:2],
            [InlineFormatting type:FormattingRangeItalic delim:"*" delimLength:1],
            [InlineFormatting type:FormattingRangeUnderlined delim:"_" delimLength:1],
            [InlineFormatting type:FormattingRangeMacro open:"{{" close:"}}" delimLength:2],
            [InlineFormatting type:FormattingRangeHighlight open:"+" close:"+" delimLength:1],
            [InlineFormatting type:FormattingRangeOmission open:"/*" close:"*/" delimLength:2],
            [InlineFormatting type:FormattingRangeNote open:"[[" close:"]]" delimLength:2]
        ];
        
        NSMutableDictionary* inlineFormats = NSMutableDictionary.new;
        for (InlineFormatting* f in allFormats) {
            inlineFormats[@(f.formatType)] = f;
        }
        
        formats = inlineFormats;
    });
    
    return formats;
}

+ (NSDictionary<NSNumber*,NSString*>*)styleNames
{
    static NSDictionary* styleNames;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        styleNames = @{
            @(FormattingRangeBold): BOLD_STYLE,
            @(FormattingRangeItalic): ITALIC_STYLE,
            @(FormattingRangeUnderlined): UNDERLINE_STYLE,
            @(FormattingRangeBoldItalic): BOLDITALIC_STYLE,
            @(FormattingRangeHighlight): HIGHLIGHT_STYLE,
            @(FormattingRangeOmission): OMIT_STYLE,
            @(FormattingRangeNote): NOTE_STYLE,
            @(FormattingRangeMacro): MACRO_STYLE
        };
    });
    
    return styleNames;
}
+ (NSString* _Nullable)styleNameFor:(FormattedRange)formatting
{
    return InlineFormatting.styleNames[@(formatting)];
}

+ (instancetype)type:(FormattedRange)type delim:(char*)delim delimLength:(NSUInteger)delimLength
{
    return [InlineFormatting.alloc initWithType:type open:delim openLength:delimLength close:delim closeLength:delimLength];
}

+ (instancetype)type:(FormattedRange)type open:(char*)open close:(char*)close delimLength:(NSUInteger)delimLength
{
    return [InlineFormatting.alloc initWithType:type open:open openLength:delimLength close:close closeLength:delimLength];
}


+ (instancetype)type:(FormattedRange)type open:(char*)open openLength:(NSUInteger)openLength close:(char*)close closeLength:(NSUInteger)closeLength
{
    return [InlineFormatting.alloc initWithType:type open:open openLength:openLength close:close closeLength:closeLength];
}

- (instancetype)initWithType:(FormattedRange)type open:(char*)open openLength:(NSUInteger)openLength close:(char*)close closeLength:(NSUInteger)closeLength
{
    self = [super init];
    if (self) {
        self.formatType = type;
        self.open = open;
        self.openLength = openLength;
        self.close = close;
        self.closeLength = closeLength;
    }
    return self;
}




@end
