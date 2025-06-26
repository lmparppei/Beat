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

@property (weak, nonatomic) id<BeatEditorDelegate> delegate;
@property (nonatomic) bool didProcessForcedCharacterCue;

@property (nonatomic) Line* _Nullable lineBeingFormatted;
@property (nonatomic) bool formatting;

/// Set this to use a static parser instead of delegate's parser
@property (nonatomic) ContinuousFountainParser* staticParser;

- (instancetype)initWithTextStorage:(NSMutableAttributedString*)textStorage;

/// Applies any required formatting changes from the parser
- (void)applyFormatChanges;

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
/// Reformats all lines in given index set
- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices;

- (void)forceFormatChangesInRange:(NSRange)range;

- (void)formatAllAsynchronously;


#pragma mark - Text color

/// Reset text color for a single line
- (void)setTextColorFor:(Line*)line;

- (void)refreshRevisionTextColors;
- (void)refreshRevisionTextColorsInRange:(NSRange)range;
- (void)refreshTextColorsForTypes:(NSIndexSet*)types range:(NSRange)range;


#pragma mark - Backgrounds

/// Refreshes the backgrounds and foreground revision colors in all lines. The method name is a bit confusing because of legacy reasons.
- (void)refreshBackgroundForAllLines;

/// Renders background for this line range
- (void)refreshBackgroundForLine:(Line*)line clearFirst:(bool)clear;

/// Redraws backgrounds in given range
- (void)refreshBackgroundForRange:(NSRange)range;


@end

NS_ASSUME_NONNULL_END
