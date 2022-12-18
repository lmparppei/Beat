//
//  BeatPagination.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

#import "BeatPaginationPage.h"

NS_ASSUME_NONNULL_BEGIN

@class BeatFonts;
@class Styles;
@class BeatPagination;
@class BeatPaginationPage;
@class BeatPaginationBlock;

@protocol BeatPaginationDelegate
@property (nonatomic) BeatExportSettings *settings;
- (void)paginationFinished:(BeatPagination*)pagination;
@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;

@property (nonatomic, readonly) Styles* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFonts *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageData;
@property (nonatomic, readonly) NSArray<Line*>* __nullable lines;
- (NSDictionary*)attributesForLine:(Line*)line dualDialogue:(bool)isDualDialogue;
@end

@interface BeatPagination : NSObject
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageData;
@property (nonatomic) bool success;
@property (nonatomic) bool canceled;

@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) NSDate* startTime;
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;

+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate;
+ (BeatPagination*)newLivePaginationWithScreenplay:(BeatScreenplay*)screenplay changeAt:(NSInteger)location delegate:(id<BeatPaginationDelegate>)delegate;
+ (Line*)contdLineFor:(Line*)line;
+ (Line*)moreLineFor:(Line*)line;
+ (CGFloat) lineHeight;

- (void)paginate;
@end

NS_ASSUME_NONNULL_END
