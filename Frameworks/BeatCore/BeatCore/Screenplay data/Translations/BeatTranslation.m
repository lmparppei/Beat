//
//  BeatTranslation.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.4.2023.
//

#import "BeatTranslation.h"
#import "BeatEditorDelegate.h"


@implementation BeatTranslation

+(BOOL)linesHaveOriginalContent:(NSArray<Line*>*)lines {
    for (Line* line in lines) {
        if (line.originalString.length > 0) return true;
    }
    
    return false;
}

+(void)storeOriginalContent:(NSArray<Line*>*)lines {
    for (Line* line in lines) {
        line.originalString = line.string;
    }
}

@end
