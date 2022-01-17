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

#if TARGET_OS_IOS
    #define BeatFont UIFont
#else
    #define BeatFont NSFont
    #import <Cocoa/Cocoa.h>
#endif

@protocol BeatPaginatorExports <JSExport>
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (strong, nonatomic) NSMutableArray<NSMutableArray*> *pages;
@property (readonly) CGFloat lastPageHeight;
- (void)paginateLines:(NSArray*)lines;
- (void)paginate;
- (NSArray*)lengthInEights;
- (void)setPageSize:(BeatPaperSize)pageSize;
@end

@protocol BeatPaginatorDelegate <NSObject>
- (NSArray*)lines;
- (NSString*)text;
@end

@interface BeatPaginator : NSObject <BeatPaginatorExports>

@property (weak) id<BeatPaginatorDelegate> delegate;
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (nonatomic, readonly) NSArray* lengthInEights;
@property (nonatomic) CGSize paperSize;
@property (readonly) CGFloat lastPageHeight;
@property (strong, nonatomic) NSMutableArray<NSMutableArray*> *pages;

// For live pagination
@property (strong, nonatomic) NSMutableArray *pageBreaks;
@property (strong, nonatomic) NSMutableArray *pageInfo;

- (id)initWithScript:(NSArray*)elements;
- (id)initForLivePagination:(NSDocument*)document;
- (id)initForLivePagination:(NSDocument*)document withElements:(NSArray*)elements;
- (id)initWithScript:(NSArray*)elements document:(NSDocument*)document;
- (id)initWithScript:(NSArray *)elements printInfo:(NSPrintInfo*)printInfo;

- (void)livePaginationFor:(NSArray*)script changeAt:(NSRange)range;
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
