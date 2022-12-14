//
//  BeatPagination.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This is an Objective C port of native pagination / rendering code.
 In this iteration, pages won't return an `NSTextView`, only an attributed string, to
 make the class more easily compatible with the upcoming iOS version.
 
 */

#import "BeatPagination.h"
#import "BeatFonts.h"
#import "Beat-Swift.h"
#import "BeatPaginationBlock.h"


@interface BeatPagination()
@property (nonatomic) NSArray<Line*>* lines;
@property (nonatomic) NSDictionary<NSString*, NSArray<NSString*>*>* titlePageData;
@property (nonatomic) BeatFonts* fonts;
@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) Styles* styles;
@property (nonatomic) NSInteger location;

@property (nonatomic) bool canceled;
@property (nonatomic) bool success;

@property (weak, nonatomic) id<BeatPaginationDelegate> delegate;

@property (nonatomic) NSMutableArray<Line*>* queue;
@property (nonatomic) NSArray<BeatPaginationPage*>* cachedPages;
@property (nonatomic) BeatPaginationPage* currentPage;

@property (nonatomic) NSDate* startTime;
@end

@implementation BeatPagination

+ (CGFloat) lineHeight; {
	return 12.0;
}

@end
