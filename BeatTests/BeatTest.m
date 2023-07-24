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

- (void) test {
	_printer = [[WebPrinter alloc] init];
	[_printer printHtml:@"<h1>Test!</h1>" printInfo:NSPrintInfo.sharedPrintInfo];
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
	"HAHMO\n" \
	"Dialogia.\n\n" \
	"Jotain muuta.";
}

@end
