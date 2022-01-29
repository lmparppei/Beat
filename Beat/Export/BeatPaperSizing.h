//
//  BeatPaperSizing.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, BeatPaperSize) {
	BeatA4 = 0,
	BeatUSLetter
};

NS_ASSUME_NONNULL_BEGIN

@interface BeatPaperSizing : NSObject
+ (NSPrintInfo*)printInfoFor:(BeatPaperSize)size;
+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo;
+ (NSPrintInfo*)setSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo;
+ (void)setPageSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo;
@end

NS_ASSUME_NONNULL_END
