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
#import "UnzipKit.h"


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
//	NSURL *pluginURL = [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	NSURL* url = [NSBundle.mainBundle URLForResource:@"Test" withExtension:@"zip"];
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:nil];
	NSArray* list = [container listFilenames:nil];
	NSLog(@"### List: %@", list);
	//[container extractFilesTo:pluginURL.path overwrite:YES error:&error];
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
