//
//  BeatEditorFormatting.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatCore/BeatEditorDelegate.h>

#if TARGET_OS_IOS
    #define _equalTo isEqual
#else
    #define _equalTo isEqualTo
#endif

NS_ASSUME_NONNULL_BEGIN

@class ContinuousFountainParser;

typedef enum {
	titlePageSubField = typeCount + 1,
	subSection
} ParagraphStyleType;

@interface BeatEditorFormatting : NSObject

@property (nonatomic) id<BeatEditorDelegate> delegate;
@property (nonatomic) bool didProcessForcedCharacterCue;

/// Set this to use a static parser instead of delegate's parser
@property (nonatomic) ContinuousFountainParser* staticParser;

- (instancetype)initWithTextStorage:(NSMutableAttributedString*)textStorage;

/// Forces reformatting of each line
- (void)formatAllLines;
/// Formats a single line
- (void)formatLine:(Line*)line;
/// Formats a single line (for the first time if set)
- (void)formatLine:(Line*)line firstTime:(bool)firstTime;
/// Format all lines in given range (including intersecting ones)
- (void)formatLinesInRange:(NSRange)range;
/// Format all lines of given type in the whole document
- (void)formatAllLinesOfType:(LineType)type;
/// Reapplies all paragraph styles
- (void)resetSizing;

- (void)forceEmptyCharacterCue;
- (void)refreshRevisionTextColors;
- (void)refreshRevisionTextColorsInRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
