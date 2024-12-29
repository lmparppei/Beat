//
//  Line+SplitAndJoin.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

#import <BeatParsing/BeatParsing.h>

@interface Line (SplitAndJoin)

/// Joins a line into this line. Copies all stylization and offsets the formatting ranges.
- (void)joinWithLine:(Line*)line;

/// Splits the line at given index, and also formats it back to a Fountain string, even if the split happens inside a formatted range.
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index;

@end
