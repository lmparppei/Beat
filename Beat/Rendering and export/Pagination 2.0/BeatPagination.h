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
#import "BeatPaginationBlock.h"

NS_ASSUME_NONNULL_BEGIN

@class BeatFonts;
@class BeatRenderStyles;
@class BeatPagination;
@class BeatPaginationPage;
@class BeatPaginationBlock;
@class BeatPaginationManager;

@protocol BeatRendererDelegate
@property (nonatomic, weak) BeatPaginationManager* pagination;
- (NSAttributedString*)pageNumberBlockForPageNumber:(NSInteger)pageNumber;
- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block firstElementOnPage:(bool)firstElementOnPage;
@end

@protocol BeatPaginationDelegate
@property (nonatomic) id<BeatRendererDelegate> __nullable renderer;
@property (nonatomic) BeatExportSettings *settings;
- (void)paginationFinished:(BeatPagination*)pagination;

- (NSString*)contdString;
- (NSString*)moreString;
@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;
@property (nonatomic, weak) id<BeatRendererDelegate> __nullable renderer;
@property (nonatomic, readonly) BeatRenderStyles* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFonts *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
@property (nonatomic, readonly) NSArray<Line*>* __nullable lines;
@property (nonatomic, readonly) CGFloat maxPageHeight;

- (Line*)moreLineFor:(Line*)line;
- (Line*)contdLineFor:(Line*)line;
@end

@interface BeatPagination : NSObject
/// A class which conforms to `BeatRenderDelegate` protocol and renders paginated blocks as `NSAttributedString` objects. 
@property (nonatomic) id<BeatRendererDelegate> renderer;

@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
@property (nonatomic) bool success;
@property (nonatomic) bool canceled;

@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) NSDate* startTime;
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic, readonly) CGFloat maxPageHeight;

+ (BeatPagination*)newPaginationWithLines:(NSArray<Line*>*)lines delegate:(id<BeatPaginationDelegate>)delegate;
+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages livePagination:(bool)livePagination changeAt:(NSInteger)changeAt;

//+ (Line*)contdLineFor:(Line*)line;
//+ (Line*)moreLineFor:(Line*)line;
+ (CGFloat)lineHeight;

- (void)paginate;
- (NSInteger)findPageIndexForLine:(Line*)line;
- (CGFloat)heightForScene:(OutlineScene*)scene;
@end

NS_ASSUME_NONNULL_END
