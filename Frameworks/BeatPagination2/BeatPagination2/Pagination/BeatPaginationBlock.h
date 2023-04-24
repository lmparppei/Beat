//
//  BeatPaginationBlock.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN
@protocol BeatPageDelegate;

@interface BeatPaginationBlock : NSObject
@property (weak, nonatomic) id<BeatPageDelegate> delegate;

@property (nonatomic) NSArray<Line*>* lines;
@property (nonatomic) CGFloat topMargin;
@property (nonatomic) LineType type;

/// Contains the rendered string. Use this property only after rendering.
@property (nonatomic) NSAttributedString* renderedString;

@property (nonatomic) bool dualDialogueElement;
@property (nonatomic) bool dualDialogueContainer;

// Left/right dialogue blocks for rendering
@property (nonatomic) BeatPaginationBlock* leftColumnBlock;
@property (nonatomic) BeatPaginationBlock* rightColumnBlock;

// Stored dialogue blocks
@property (nonatomic) NSMutableAttributedString* leftColumn;
@property (nonatomic) NSMutableAttributedString* rightColumn;

+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate;
+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement;

- (NSArray*)breakBlockWithRemainingSpace:(CGFloat)remainingSpace;
- (CGFloat)height;
- (bool)containsLine:(Line*)line;

@end

NS_ASSUME_NONNULL_END
