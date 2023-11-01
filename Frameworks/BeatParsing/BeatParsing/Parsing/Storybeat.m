//
//  Storybeat.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "Storybeat.h"

@implementation Storybeat
/// Creates a storyline and automatically divides storyline and beat.
+ (Storybeat*)line:(Line*)line scene:(OutlineScene*)scene string:(NSString*)string range:(NSRange)range
{
	NSString *storyline = @"", *beat = @"";
	
	if ([string containsString:@":"]) {
		NSUInteger loc = [string rangeOfString:@":"].location;
		if (loc > 0) {
			storyline = [string substringToIndex:loc];
		} else {
			storyline = [string substringFromIndex:1];
		}
		
		if (loc != string.length) {
			beat = [string substringFromIndex:loc + 1];
		}
		
	} else {
		storyline = string;
	}
	
	return [Storybeat line:line scene:scene storyline:storyline beat:beat range:range];
}

+ (Storybeat*)line:(Line*)line scene:(OutlineScene*)scene storyline:(NSString*)storyline beat:(NSString*)beat range:(NSRange)range {
	Storybeat *storybeat = Storybeat.new;
	storybeat.line = line;
	storybeat.beat = [beat stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	storybeat.storyline = [storyline stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].uppercaseString;
	storybeat.scene = scene;
	storybeat.rangeInLine = range;
	return storybeat;
}
+ (NSString*)stringWithStorylineNames:(NSArray<NSString*>*)storylineNames {
	
	NSMutableString *string = [NSMutableString stringWithString:@"[[Beat "];
	[string appendString:[storylineNames componentsJoinedByString:@", "]];
	[string appendString:@"]]"];
	return string;
}
+ (NSString*)stringWithBeats:(NSArray<Storybeat*>*)beats {
	NSString *string = @"[[Beat";
	for (Storybeat* beat in beats) {
		string = [string stringByAppendingFormat:@" %@", beat.stringified];
		if (beat != beats.lastObject) string = [string stringByAppendingString:@","];
	}
	string = [string stringByAppendingString:@"]]"];
	return string;
}
- (NSString*)stringified {
	NSString *str = [NSString stringWithString:self.storyline];
	if (self.beat.length) str = [str stringByAppendingFormat:@": %@", self.beat];
	return str;
}

- (NSDictionary*)forSerialization {
	return @{
		@"storyline": (self.storyline) ? _storyline : @"",
		@"beat": (self.beat) ? _beat : @"",
	};
}

#pragma mark - Debug

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@ (at %lu, %lu)", self.storyline, self.beat, self.rangeInLine.location, self.rangeInLine.length];
}

@end
