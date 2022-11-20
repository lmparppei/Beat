//
//  BeatScreenplay.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 7.10.2022.
//

#import "BeatScreenplay.h"
#import "ContinuousFountainParser.h"
#import "BeatExportSettings.h"

#pragma mark - Screenplay meta-object

@implementation BeatScreenplay
/**
 Usage: [BeatScreenplay from:parser settings:settings];
 */

+(instancetype)from:(ContinuousFountainParser*)parser {
    return [self from:parser settings:nil];
}
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings {
    BeatScreenplay *screenplay = BeatScreenplay.new;
    screenplay.titlePage = [ContinuousFountainParser titlePageForString:parser.titlePageAsString];
    screenplay.titlePageLines = parser.getTitlePage;
    
    if (settings.printNotes) screenplay.lines = [parser preprocessForPrintingPrintNotes:YES];
    else screenplay.lines = parser.preprocessForPrinting;
    
    return screenplay;
}

@end
