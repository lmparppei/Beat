//
//  FountainPaginator.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Line.h"

#if TARGET_OS_IPHONE
    #define BeatFont UIFont
#else
    #define BeatFont NSFont
    #import <Cocoa/Cocoa.h>
#endif

// @class FNScript, FNElement;

@interface FountainPaginator : NSObject

@property (nonatomic, readonly) NSUInteger numberOfPages;
@property (nonatomic) CGSize paperSize;
@property (strong, nonatomic) NSMutableArray *pages;
@property (strong, nonatomic) NSMutableArray *pageBreaks;

- (id)initWithScript:(NSArray*)elements;
- (id)initWithScript:(NSArray*)elements document:(NSDocument*)document;
- (id)initWithScript:(NSArray*)elements paperSize:(CGSize)paperSize;
- (void)paginate;
- (void)paginateForSize:(CGSize)pageSize;
- (NSArray *)pageAtIndex:(NSUInteger)index;

// Helper methods
+ (CGFloat)lineHeight;
+ (CGFloat)spaceBeforeForElement:(Line *)element;
+ (CGFloat)spaceBeforeForLine:(Line *)line;
//+ (NSInteger)leftMarginForElement:(FNElement *)element;
+ (NSInteger)widthForElement:(Line *)element;
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight;

@end
