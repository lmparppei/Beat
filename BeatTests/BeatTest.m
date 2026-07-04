//
//  BeatTest.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 26.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/* unit tests didn't work, so yeah....... */

#import "BeatTest.h"

#import "ContinuousFountainParser.h"
#import "Line.h"
#import "BeatPlugin.h"
#import "WebPrinter.h"

@interface BeatTest()
@property (nonatomic) WebPrinter* printer;
@end

@implementation BeatTest

- (instancetype)init
{
	self = [super init];
	if (self) {
		NSLog(@"######### RUNNING TESTS #########");
		[self test];
	}
	return self;
}


@end
