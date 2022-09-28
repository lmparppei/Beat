//
//  FountainPaginator.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Line.h"
#import "BeatPaperSizing.h"
#import "BeatExportSettings.h"

#if TARGET_OS_IOS
    #define BeatFont UIFont
	#define BeatDocument UIDocument
	#define BetPrintInfo UIPrintInfo
	#import <UIKit/UIKit.h>
#else
    #define BeatFont NSFont
	#define BeatDocument NSDocument
	#define BetPrintInfo NSPrintInfo
    #import <Cocoa/Cocoa.h>
#endif

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool A4;
@property (nonatomic, readonly) BeatFont *font;
@property (nonatomic) bool livePagination;
- (NSInteger)heightForBlock:(NSArray*)block;
@end

@interface BeatPage:NSObject
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSInteger y;
@property (nonatomic) NSInteger maxHeight;
- (NSUInteger)count;
- (NSMutableArray*)contents;
- (NSInteger)remainingSpace;
- (NSInteger)remainingSpaceWithBlock:(NSArray<Line*>*)block;
@end

@protocol BeatPaginatorExports <JSExport>
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (strong, nonatomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
@property (readonly) CGFloat lastPageHeight;
- (void)paginateLines:(NSArray*)lines;
- (void)paginate;
- (NSArray*)lengthInEights;
- (void)setPageSize:(BeatPaperSize)pageSize;
@end

@protocol BeatPaginatorDelegate <NSObject>
- (NSMutableArray<Line*>*)lines;
- (NSString*)text;
@end

@interface BeatPaginator : NSObject <BeatPaginatorExports, BeatPageDelegate>

@property (weak) id<BeatPaginatorDelegate> delegate;
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (nonatomic, readonly) NSArray* lengthInEights;
@property (nonatomic) CGSize paperSize;
@property (readonly) CGFloat lastPageHeight;
@property (strong, nonatomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
@property (nonatomic) bool livePagination;
@property (nonatomic) NSMutableIndexSet *updatedPages;

// For live pagination
@property (strong, nonatomic) NSMutableArray *pageBreaks;
@property (strong, nonatomic) NSMutableArray *pageInfo;

- (id)initWithScript:(NSArray *)elements settings:(BeatExportSettings*)settings;
- (id)initForLivePagination:(BeatDocument*)document;
- (id)initForLivePagination:(BeatDocument*)document withElements:(NSArray*)elements;
#if !TARGET_OS_IOS
- (id)initWithScript:(NSArray *)elements printInfo:(NSPrintInfo*)printInfo;
#endif

- (void)livePaginationFor:(NSArray*)script changeAt:(NSUInteger)location;
- (void)paginate;
- (NSArray *)pageAtIndex:(NSUInteger)index;
- (void)setPageSize:(BeatPaperSize)pageSize;

- (NSInteger)pageNumberFor:(NSInteger)location;
- (NSArray*)lengthInEights;

// Helper methods
+ (CGFloat)lineHeight;
+ (CGFloat)spaceBeforeForLine:(Line *)line;
- (NSInteger)widthForElement:(Line *)element;
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight;

@end
