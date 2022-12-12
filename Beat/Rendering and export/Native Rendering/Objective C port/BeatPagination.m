//
//  BeatPagination.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPagination.h"
#import "BeatFonts.h"
#import "Beat-Swift.h"

@interface BeatPagination()
@property (nonatomic) NSArray<Line*>* lines;
@property (nonatomic) NSDictionary<NSString*, NSArray<NSString*>*>* titlePageData;
@property (nonatomic) BeatFonts *fonts;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) Styles *styles;
@property (nonatomic) NSInteger location;


/*
 @objc var pages = [BeatPageView]()
 
 var cachedPages:[BeatPageView]
 
 var currentPage:BeatPageView? = nil
 var queue:[Line] = []
 var startTime:Date
 
 weak var delegate:BeatRenderOperationDelegate?

 @objc var canceled = false
 @objc var success = false
 */
@end

@implementation BeatPagination

@end
