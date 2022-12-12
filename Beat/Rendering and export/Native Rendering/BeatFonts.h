//
//  BeatFonts.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatFonts : NSObject
@property (nonatomic) NSFont *courier;
@property (nonatomic) NSFont *boldCourier;
@property (nonatomic) NSFont *italicCourier;
@property (nonatomic) NSFont *boldItalicCourier;

+ (BeatFonts*)sharedFonts;
+ (CGFloat)characterWidth;
@end

NS_ASSUME_NONNULL_END
