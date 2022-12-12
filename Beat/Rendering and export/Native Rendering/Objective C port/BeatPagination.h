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

NS_ASSUME_NONNULL_BEGIN
/*
 protocol BeatPageViewDelegate:NSObject {
	 var canceled:Bool { get }
	 var styles:Styles { get }
	 var settings:BeatExportSettings { get }
	 var fonts:BeatFonts { get }
	 var pages:[BeatPageView] { get }
	 var titlePageData:[[String:[String]]]? { get set }
	 var lines:[Line] { get }
 }
 
 */

@class BeatFonts;
@class Styles;

@protocol BeatPaginationDelegate
@property (nonatomic) bool canceled;
@property (nonatomic) Styles* styles;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) BeatFonts *fonts;
@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;
@property (nonatomic, readonly) Styles* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFonts *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSDictionary<NSString*, NSArray<NSString*>*>* titlePageData;
@property (nonatomic, readonly) NSArray<Line*>* lines;
@end

@interface BeatPagination : NSObject
+ (CGFloat) lineHeight;
@end

NS_ASSUME_NONNULL_END
