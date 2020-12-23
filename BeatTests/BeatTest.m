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
#import "BeatHTMLScript.h"
#import "BeatScriptParser.h"

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
	/*
	BeatScriptParser *parser = [[BeatScriptParser alloc] init];
	
	NSString *string = [self testString];
	ContinousFountainParser *fountainParser = [[ContinousFountainParser alloc] initWithString:string];
		
	NSString *script = @"Beat.log(Lines[0].string)";
	parser.lines = fountainParser.lines;
	[parser runScriptWithString:script];
	 */
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
