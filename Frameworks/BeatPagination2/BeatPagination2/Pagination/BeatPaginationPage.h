//
//  BeatPaginationPage.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN
@protocol BeatPageDelegate;
@class BeatPaginationBlock;
@class BeatPageBreak;

@protocol BeatPaginationPageExports <JSExport>
@property (nonatomic, readonly) BeatPageBreak *pageBreak;
//@property (nonatomic, readonly) NSMutableArray<BeatPaginationBlock*>* blocks;
@property (nonatomic, readonly) CGFloat maxHeight;
@property (nonatomic, readonly) CGFloat remainingSpace;
@property (nonatomic, readonly) NSArray<Line*>* lines;
@property (nonatomic, readonly) NSString* customPageNumber;

-(NSRange)representedRange;
-(NSRange)safeRange;

- (CGFloat)positionOfBlock:(BeatPaginationBlock*)block;
- (CGFloat)actualPositionOfBlock:(BeatPaginationBlock*)block;

- (CGFloat)positionOfBlockForLine:(Line*)line;
- (CGFloat)actualPositionOfBlockForLine:(Line*)line;

@end

@interface BeatPaginationPage : NSObject <BeatPaginationPageExports>
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
@property (nonatomic) BeatPageBreak *pageBreak;
@property (nonatomic) NSMutableArray<BeatPaginationBlock*>* blocks;
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) CGFloat remainingSpace;
@property (nonatomic) NSString* customPageNumber;

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate;
-(BeatPaginationPage*)copyWithDelegate:(id)delegate;

-(void)addBlock:(BeatPaginationBlock*)block;
-(void)clearUntil:(Line*)line;
- (void)invalidateRender;
-(NSRange)safeRange;
-(NSRange)representedRange;
-(NSAttributedString*)attributedString;
-(NSArray<Line*>*)lines;

- (NSInteger)indexForLineAtPosition:(NSInteger)position;
- (NSInteger)findSafeLineFromIndex:(NSInteger)index;
- (NSInteger)blockIndexForLine:(Line*)line;
- (NSInteger)nearestBlockIndexForLine:(Line*)line;
- (NSInteger)nearestBlockIndexForRange:(NSRange)range;
- (NSRange)rangeForLocation:(NSInteger)location;
- (CGFloat)positionOfBlock:(BeatPaginationBlock*)block;
- (CGFloat)positionOfBlockForLine:(Line*)line;
@end

NS_ASSUME_NONNULL_END
