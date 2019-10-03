//
//  FountainReport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"
#import "Line.h"

@interface FountainReport : NSObject
{
}
@property NSMutableArray * characters;
@property NSMutableArray * lines;
@property NSMutableDictionary<NSString *, NSNumber *>* characterLines;

- (NSString*) createReport:(NSMutableArray*)lines;

@end
