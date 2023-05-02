//
//  FountainPaginator.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatPaginationOperationDelegate.h"

@class BeatPaginationOperation;

#if TARGET_OS_IOS
    #define BeatFont UIFont
	#define BeatDocument UIDocument
	#define BeatPrintInfo UIPrintInfo
	#import <UIKit/UIKit.h>
#else
    #define BeatFont NSFont
	#define BeatDocument NSDocument
	#define BeatPrintInfo NSPrintInfo
    #import <Cocoa/Cocoa.h>
#endif

@protocol BeatPaginatorExports <JSExport>
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (strong, atomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
@property (readonly) CGFloat lastPageHeight;
- (void)paginateLines:(NSArray*)lines;
- (NSArray*)lengthInEights;
- (void)setPageSize:(BeatPaperSize)pageSize;
@end

@protocol BeatPaginatorDelegate <NSObject>
- (void)paginationDidFinish:(NSArray*)pages pageBreaks:(NSArray*)pageBreaks;
- (NSMutableArray<Line*>*)lines;
- (NSString*)text;
- (NSInteger)spaceBeforeHeading;
@end

@interface BeatPaginator : NSObject <BeatPaginatorExports, BeatPaginationOperationDelegate>

@property (weak) id<BeatPaginatorDelegate> delegate;
@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (nonatomic, readonly) NSArray* lengthInEights;
@property (atomic) CGSize paperSize;
@property (nonatomic) CGFloat lastPageHeight;
@property (strong, atomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
@property (nonatomic) NSMutableIndexSet *updatedPages;

@property (atomic) BeatExportSettings *settings;

@property (nonatomic) BeatFont *font;

@property (weak, nonatomic) BeatDocument *document;
@property (atomic) BeatPrintInfo *printInfo;
@property (atomic) bool printNotes;

// For live pagination
@property (atomic) bool livePagination;
@property (strong, nonatomic) NSMutableArray *pageBreaks;
@property (strong, nonatomic) NSMutableArray *pageInfo;

- (id)initWithScript:(NSArray *)elements settings:(BeatExportSettings*)settings;
- (id)initForLivePagination:(BeatDocument*)document;
- (id)initForLivePagination:(BeatDocument*)document withElements:(NSArray*)elements;
#if !TARGET_OS_IOS
- (id)initWithScript:(NSArray *)elements printInfo:(NSPrintInfo*)printInfo;
#endif

- (void)livePaginationFor:(NSArray*)script changeAt:(NSUInteger)location;
- (NSArray *)pageAtIndex:(NSUInteger)index;
- (void)setPageSize:(BeatPaperSize)pageSize;

- (NSInteger)pageNumberFor:(NSInteger)location;
- (NSArray*)lengthInEights;

// Helper methods
- (CGFloat)spaceBeforeForLine:(Line *)line;
- (Line*)moreLineFor:(Line*)line;
- (Line*)contdLineFor:(Line*)line;

+ (CGFloat)lineHeight;
+ (CGFloat)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight;

// Pagination operation finished
- (void)paginationFinished:(BeatPaginationOperation*)operation;

@end
