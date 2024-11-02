//
//  ContinuousFountainParser+Notes.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.10.2024.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContinuousFountainParser (Notes)
- (void)parseNotesFor:(Line*)line at:(NSInteger)lineIndex oldType:(LineType)oldType;
@end

NS_ASSUME_NONNULL_END
