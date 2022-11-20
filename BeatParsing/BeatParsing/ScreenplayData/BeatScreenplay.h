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
+(instancetype)from:(ContinuousFountainParser*)parser;
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings;
@property (nonatomic) NSArray <Line*>* lines;
@property (nonatomic) NSArray <Line*>* titlePageLines;
@property (nonatomic) NSArray <NSDictionary<NSString*, NSArray<NSString*>*>*> *titlePage;
@end
