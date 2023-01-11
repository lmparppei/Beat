//
//  BeatPaginationOperation.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatPageDelegate.h"
#import "BeatPaginationOperationDelegate.h"

#if TARGET_OS_IOS
	#define BeatFont UIFont
	#define BeatDocument UIDocument
	#define BeatPrintInfo UIPrintInfo
#else
	#define BeatFont NSFont
	#define BeatDocument NSDocument
	#define BeatPrintInfo NSPrintInfo
#endif

@class BeatPage;
@class BeatExportSettings;

@interface BeatPaginationOperation:NSObject <BeatPageDelegate>

@property (nonatomic, weak) id<BeatPaginationOperationDelegate> paginator;

@property (nonatomic) NSArray* script;
@property (nonatomic) NSInteger location;
@property (nonatomic, weak) NSThread* thread;
@property (nonatomic) bool running;
@property (nonatomic) bool cancelled;
@property (nonatomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
@property (nonatomic) NSMutableArray<NSDictionary*>* pageBreaks;
@property (nonatomic) CGFloat lastPageHeight;
@property (nonatomic) NSDate *startTime;

@property (nonatomic) bool success;

@property (atomic) bool livePagination;
- (id)initWithElements:(NSArray *)elements paginator:(id<BeatPaginationOperationDelegate>)paginator;
- (id)initWithElements:(NSArray*)elements livePagination:(bool)livePagination paginator:(id<BeatPaginationOperationDelegate>)paginator cachedPages:(NSArray*)cachedPages cachedPageBreaks:(NSArray*)cachedBreaks changeAt:(NSInteger)changeAt;

- (void)paginate;
- (void)paginateForEditor;

- (void)cancel;

@end
