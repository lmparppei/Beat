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
@property (nonatomic) NSArray<Line*>* lines;
@property (nonatomic) CGFloat topMargin;
@property (nonatomic) LineType type;

+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate;
+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement;

- (NSAttributedString*)attributedString;
- (NSArray*)breakBlockWithRemainingSpace:(CGFloat)remainingSpace;
- (CGFloat)height;

@end

NS_ASSUME_NONNULL_END
