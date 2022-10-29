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
#else
    #import <Cocoa/Cocoa.h>
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

#if TARGET_OS_IOS
	+ (CGSize)printableAreaFor:(BeatPaperSize)size;
#else
	// macOS paper sizing
	+ (NSPrintInfo*)printInfoFor:(BeatPaperSize)size;
	+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo;
	+ (NSPrintInfo*)setSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo;
	+ (void)setPageSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo;

#endif

+ (CGSize)a4;
+ (CGSize)usLetter;
+ (CGSize)sizeFor:(BeatPaperSize)size;

@end

NS_ASSUME_NONNULL_END
