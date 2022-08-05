//
//  BeatEditTracking.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"
#import "Line.h"
#import "BeatComparison.h"

@protocol BeatEditTrackingDelegate <NSObject>
@property (weak, readonly) ContinuousFountainParser *parser;
- (NSString*)text;
@end

@interface BeatEditTracking : NSObject
-(instancetype)initWithString:(NSString*)text delegate:(id<BeatEditTrackingDelegate>)delegate;
@property (nonatomic) id<BeatEditTrackingDelegate> delegate;
@property (nonatomic) NSArray<Line*> *origin;
@property (nonatomic) NSString *text;
@property (nonatomic) BeatComparison *comparison;
@end
