//
//  BeatRevisionTracking.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatRevisionTracking : NSObject
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string parser:(ContinuousFountainParser*)parser;
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string;
//@property (nonatomic) NSMutableIndexSet *additions;
//@property (nonatomic) NSMutableIndexSet *removals;
@end

NS_ASSUME_NONNULL_END
