//
//  OutlineExtractor.h
//  Writer
//
//  Created by Hendrik Noeller on 11.05.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ContinousFountainParser.h"

@interface OutlineExtractor : NSObject

+ (NSString*)outlineFromParse:(ContinousFountainParser*)parser;

@end
