//
//  BeatPaginationTest.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationTest.h"
#import <BeatParsing/BeatParsing.h>
#import "BeatPaginator.h"
#import "BeatPagination.h"
#import "BeatMeasure.h"

@implementation BeatPaginationTest

+ (void)testOldVersion:(NSArray*)lines settings:(BeatExportSettings*)settings {
	[BeatMeasure start:@"### Old version"];
	BeatPaginator* paginator = [BeatPaginator.alloc initWithScript:lines settings:settings];
	NSLog(@"Number of pages: %lu", paginator.numberOfPages);
	[BeatMeasure end:@"### Old version"];
}

+ (void)testNewVersion:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate {
	[BeatMeasure start:@"### New version"];
	
	BeatPagination* pagination = [BeatPagination newPaginationWithScreenplay:screenplay delegate:delegate];
	[pagination paginate];
	NSLog(@"Number of page: %lu", pagination.pages.count);
	
	[BeatMeasure end:@"### New version"];
}

@end
