//
//  BeatPagination.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "BeatPaginationPage.h"
#import "BeatPaginationBlock.h"

#if TARGET_OS_IOS
    #define BXFont UIFont
    #define uuidEqualTo isEqual
    #import <UIKit/UIKit.h>
#else
    #define BXFont NSFont
    #define uuidEqualTo isEqualTo
    #import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class BeatFonts;
@class BeatStylesheet;
@class BeatPagination;
@class BeatPaginationPage;
@class BeatPaginationBlock;
@class BeatPaginationManager;

@protocol BeatRendererDelegate
@property (nonatomic, weak) BeatPaginationManager* pagination;
- (NSAttributedString*)pageNumberBlockForPageNumber:(NSInteger)pageNumber;
- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block firstElementOnPage:(bool)firstElementOnPage;
- (void)reloadStyles;
@end

@protocol BeatPaginationDelegate
@property (nonatomic) id<BeatRendererDelegate> __nullable renderer;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) id<BeatEditorDelegate> __nullable editorDelegate;
- (void)paginationFinished:(BeatPagination*)pagination;
@end

@protocol BeatPaginationExports <JSExport>
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;

@property (nonatomic) bool success;
@property (nonatomic, readonly) CGFloat maxPageHeight;

- (NSInteger)findPageIndexForLine:(Line*)line;
- (NSInteger)findPageIndexAt:(NSInteger)position;
- (CGFloat)heightForScene:(OutlineScene*)scene;
- (CGFloat)heightForRange:(NSRange)range;

- (NSInteger)pageIndexForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberAt:(NSInteger)location;

@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;
@property (nonatomic, weak) id<BeatRendererDelegate> __nullable renderer;
@property (nonatomic, readonly) BeatStylesheet* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFonts *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
@property (nonatomic, readonly) NSArray<Line*>* __nullable lines;
@property (nonatomic, readonly) CGFloat maxPageHeight;

- (NSParagraphStyle*)paragraphStyleFor:(NSString*)lineType;

- (Line*)moreLineFor:(Line*)line;
- (Line*)contdLineFor:(Line*)line;
- (NSDictionary<NSUUID*, Line*>*)uuids;
@end

@interface BeatPagination : NSObject <BeatPaginationExports>
/// A class which conforms to `BeatRenderDelegate` protocol and renders paginated blocks as `NSAttributedString` objects. 
@property (weak, nonatomic) id<BeatRendererDelegate> renderer;

@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
@property (nonatomic) bool success;
@property (nonatomic) bool canceled;
@property (nonatomic) bool running;

@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) NSDate* startTime;
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic, readonly) CGFloat maxPageHeight;

+ (BeatPagination*)newPaginationWithLines:(NSArray<Line*>*)lines delegate:(__weak id<BeatPaginationDelegate>)delegate;
+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(__weak id<BeatPaginationDelegate>)delegate cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages livePagination:(bool)livePagination changeAt:(NSInteger)changeAt;

//+ (Line*)contdLineFor:(Line*)line;
//+ (Line*)moreLineFor:(Line*)line;
+ (CGFloat)lineHeight;

- (void)paginate;
- (NSInteger)findPageIndexForLine:(Line*)line;
- (NSInteger)findPageIndexAt:(NSInteger)position;
- (CGFloat)heightForScene:(OutlineScene*)scene;
- (CGFloat)heightForRange:(NSRange)range;

- (NSInteger)pageIndexForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberAt:(NSInteger)location;

- (NSDictionary<NSUUID*, Line*>*)uuids;

- (NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>*)titlePage;
@end

NS_ASSUME_NONNULL_END
