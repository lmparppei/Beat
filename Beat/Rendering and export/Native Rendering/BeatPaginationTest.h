//
//  BeatPaginationTest.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
NS_ASSUME_NONNULL_BEGIN
@class BeatExportSettings;
@protocol BeatPaginationDelegate;
@interface BeatPaginationTest : NSObject
+ (void)testOldVersion:(NSArray*)lines settings:(BeatExportSettings*)settings;
+ (void)testNewVersion:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
