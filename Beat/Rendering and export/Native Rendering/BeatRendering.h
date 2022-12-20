//
//  BeatRendering.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <BeatParsing/BeatParsing.h>

@class BeatPaginationPage;

NS_ASSUME_NONNULL_BEGIN

@interface BeatRendering : NSObject
- (instancetype)initWithSettings:(BeatExportSettings*)settings;
- (NSArray<NSAttributedString*>*)renderPages:(NSArray<BeatPaginationPage*>)pages;
@end

NS_ASSUME_NONNULL_END
