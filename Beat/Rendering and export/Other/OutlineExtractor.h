//
//  OutlineExtractor.h
//  Beat
//
//  Created by Hendrik Noeller on 11.05.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ContinuousFountainParser;
@interface OutlineExtractor : NSObject
+ (NSString*)outlineFromParse:(ContinuousFountainParser*)parser;
@end
