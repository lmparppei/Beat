//
//  BeatPagination.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

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

@protocol BeatPaginationDelegate
@property (nonatomic) bool canceled;
@property (nonatomic) id styles;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) BeatFonts *fonts;
@end

@interface BeatPagination : NSObject

@end

NS_ASSUME_NONNULL_END
