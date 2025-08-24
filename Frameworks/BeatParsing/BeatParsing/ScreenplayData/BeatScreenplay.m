//
//  BeatScreenplay.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 7.10.2022.
//

#import "BeatScreenplay.h"
#import "ContinuousFountainParser.h"
#import "ContinuousFountainParser+Preprocessing.h"
#import "BeatExportSettings.h"

#pragma mark - Screenplay meta-object

@implementation BeatScreenplay
/**
 Usage: [BeatScreenplay from:parser settings:settings];
 */

+(instancetype)from:(ContinuousFountainParser*)parser
{
    return [self from:parser settings:nil];
}
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings
{
    BeatScreenplay *screenplay = BeatScreenplay.new;
    screenplay.titlePage = [ContinuousFountainParser titlePageForString:parser.titlePageAsString];
    screenplay.titlePageContent = parser.parseTitlePage;
    screenplay.lines = [parser preprocessForPrintingWithExportSettings:settings];
    
    return screenplay;
}

- (NSString*)titlePageTextForField:(NSString*)field
{
    for (NSDictionary<NSString*, NSArray<NSString*>*>* dict in self.titlePage) {
        NSString* key = (NSString*)dict.allKeys.firstObject;
        if (key == nil) continue;
        
        if ([key.lowercaseString isEqualToString:field]) {
            NSArray<NSString*>* strings = dict.allValues.firstObject;
            return [strings componentsJoinedByString:@"\n"];
        }
    }
    
    return nil;
}

@end
