//
//  BeatPaperSizing.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.11.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum : NSInteger {
	BeatA4 = 0,
	BeatUSLetter
} BeatPaperSize;

NS_ASSUME_NONNULL_BEGIN

@interface BeatPaperSizing : NSObject
+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo;
+ (NSPrintInfo*)setSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo;
+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo;
@end

NS_ASSUME_NONNULL_END
