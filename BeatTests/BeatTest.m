//
//  BeatTest.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 26.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/* unit tests didn't work, so yeah....... */

#import "BeatTest.h"

#import "ContinousFountainParser.h"
#import "Line.h"

@implementation BeatTest

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self test];
	}
	return self;
}

- (void) test {
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:[self testString]];
	[parser parseChangeInRange:NSMakeRange(7, 30) withString:@""];
}

- (NSString*)testString {
	return @"INT. TESTI\n" \
	"\n" \
	"Jotain tavaraa tässä.\n" \
	"Jotain vielä lisää tässä on.\n\n"
	"HAHMO\n" \
	"Dialogia.\n\n" \
	"Jotain muuta.";
}

@end
