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
#import "BeatHTMLScript.h"
#import "BeatPluginParser.h"
#import "NSString+Levenshtein.h"


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
	NSString *string = @"Tämä on testi!";
	NSArray *alt = @[@"Tämä on testi!", @"Tämäkin on testi", @"Pelkkä testi", @"Testi"];
	
	for (NSString *str in alt) {
		CGFloat result = [str compareWithString:string];
		NSLog(@"%@: result %f", str, result);
	}
	
}

- (NSString*)testString {
	return @"INT. TESTI\n\n" \
	"Jotain tavaraa tässä.\n" \
	"Tätä riviä ei ole uudessa?\n" \
	"Jotain vielä lisää tässä on.\n\n" \
	"HAHMO\n" \
	"Dialogia.\n\n" \
	"Jotain muuta.";
}

- (NSString*)testString2 {
	return @"INT. TESTI\n" \
	"\n" \
	"Jotain tavaraa tässä.\n" \
	"Tämäkin on uusi.\n" \
	"Jotain vielä lisää tässä on.\n\n"
	"Täs muuten kolmas rivi lol.\n\n"
	"HAHMO\n" \
	"Dialogia.\n\n" \
	"Jotain muuta.";
}

@end
