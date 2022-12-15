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

@protocol BeatPaginationDelegate
@property (nonatomic) bool canceled;
@property (nonatomic) Styles* styles;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) BeatFonts *fonts;
- (void)paginationFinished:(BeatPagination*)pagination;
@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;
@property (nonatomic, readonly) Styles* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFonts *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSDictionary<NSString*, NSArray<NSString*>*>* __nullable titlePageData;
@property (nonatomic, readonly) NSArray<Line*>* __nullable lines;
@end

@interface BeatPagination : NSObject
+ (CGFloat) lineHeight;
@end

NS_ASSUME_NONNULL_END
