//
//  BeatPageBreak.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 A simple class to provide information about the page break position in editor.
 
 */

#import "BeatPageBreak.h"
#import <BeatParsing/BeatParsing.h>

@implementation BeatPageBreak

-(instancetype)initWithY:(CGFloat)y element:(Line*)line lineHeight:(CGFloat)lineHeight
{
	return [BeatPageBreak.alloc initWithY:y element:line lineHeight:lineHeight reason:@""];
}

-(instancetype)initWithY:(CGFloat)y element:(Line*)line lineHeight:(CGFloat)lineHeight reason:(NSString*)reason
{
	self = [super init];
	if (self) {
		self.y = y;
		self.element = line;
		self.reason = reason;
        self.lineHeight = lineHeight;
	}
	
	return self;
}

/// For the speculative WYSIWYG mode, we need to map *visible* index of an attributed string to the *actual* index in parsed content. To achieve this, `Line` class bakes the actual represented range to each chunk of its attributed string. This initializer handles the conversion. The layout manager delegate should take care of finding out where the line actually resides, add exclusion areas and return correct values for `shouldBreakLineByWordBeforeCharacterAtIndex:` based on the provided line break objects.
-(instancetype)initWithVisibleIndex:(NSInteger)index element:(Line*)line attributedString:(NSAttributedString* _Nullable)attrStr reason:(NSString*)reason
{
    self = [super init];
    if (self) {
        self.element = line;
        self.reason = reason;
        
        if (index == 0) {
            self.index = index;
        } else if (index == -1) {
            self.index = line.string.length;
        } else {
            // Find out the actual index
            __block NSInteger actualIndex = NSNotFound;
            [attrStr enumerateAttribute:@"BeatEditorRange" inRange:NSMakeRange(0, index) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
                NSRange representedRange = ((NSValue*)value).rangeValue;
                actualIndex = representedRange.location + range.length;
                *stop = true;
            }];
            
            if (actualIndex != NSNotFound) self.index = actualIndex;
        }
    }
    
    return self;
}

@end
