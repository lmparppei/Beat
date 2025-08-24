//
//  BeatScreenplay.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 7.10.2022.
//

#import <Foundation/Foundation.h>

@class ContinuousFountainParser;
@class BeatExportSettings;
@class Line;
@interface BeatScreenplay : NSObject
@property (nonatomic) NSArray <Line*>* lines;

/// Title page content is formed as dictionaries inside an array: `[ ["key": [Line, Line]], ... ]`
@property (nonatomic) NSArray<NSDictionary <NSString*, NSArray<Line*>*>*>* titlePageContent;
@property (nonatomic) NSArray <NSDictionary<NSString*, NSArray<NSString*>*>*> *titlePage;
@property (nonatomic) NSArray* variables;

+(instancetype)from:(ContinuousFountainParser*)parser;
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings;

- (NSString*)titlePageTextForField:(NSString*)field;

@end
