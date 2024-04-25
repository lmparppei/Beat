//
//  OutlineExtractor.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 11.05.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "OutlineExtractor.h"
#import "Beat-Swift.h"

@implementation OutlineExtractor

+ (void)register:(BeatFileExportManager*)manager
{
	// Register as export handler
	[manager registerHandlerFor:@"Outline" fileTypes:@[@"fountain", @"txt"] supportedStyles:@[@"Screenplay"] handler:^id _Nullable(id<BeatEditorDelegate> _Nonnull delegate) {

		return [OutlineExtractor outlineFromParse:delegate.parser];
	}];
}

+ (NSString*)outlineFromParse:(ContinuousFountainParser*)parser
{
    NSMutableString* result = [[NSMutableString alloc] init];
    
    Line* lastLine = nil;
    for (Line* line in parser.lines) {
        if (line.type == section || line.type == synopse || line.type == heading) {
            //To put empty lines in between types, we compare to the last lines type
            if (lastLine && (line.type == heading || lastLine.type != line.type)) {
                [result appendString:@"\n"];
            }
            lastLine = line;
            [result appendString:line.string];
            [result appendString:@"\n"];
            
        }
    }
    
    return result;
}

@end
