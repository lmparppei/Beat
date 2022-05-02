//
//  BeatPaperSizing.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define BeatPrintInfo UIPrintInfo
#else
    #import <Cocoa/Cocoa.h>
    #define BeatPrintInfo NSPrintInfo
#endif

typedef NS_ENUM(NSInteger, BeatPaperSize) {
	BeatA4 = 0,
	BeatUSLetter
};

NS_ASSUME_NONNULL_BEGIN

@interface BeatMargins: NSObject
@property (nonatomic) CGFloat top;
@property (nonatomic) CGFloat left;
@property (nonatomic) CGFloat right;
@property (nonatomic) CGFloat bottom;
+ (BeatMargins*)margins;
@end

@interface BeatPaperSizing : NSObject

+ (BeatPrintInfo*)printInfoFor:(BeatPaperSize)size;
+ (BeatPrintInfo*)setMargins:(BeatPrintInfo*)printInfo;
+ (BeatPrintInfo*)setSize:(BeatPaperSize)size printInfo:(BeatPrintInfo*)printInfo;
+ (void)setPageSize:(BeatPaperSize)size printInfo:(BeatPrintInfo*)printInfo;
@end

NS_ASSUME_NONNULL_END
