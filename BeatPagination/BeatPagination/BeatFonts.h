//
//  BeatFonts.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #define BXFont UIFont
#else
    #define BXFont NSFont
#endif

NS_ASSUME_NONNULL_BEGIN

@interface BeatFonts : NSObject
@property (nonatomic) BXFont* courier;
@property (nonatomic) BXFont* boldCourier;
@property (nonatomic) BXFont* italicCourier;
@property (nonatomic) BXFont* boldItalicCourier;

@property (nonatomic) BXFont* synopsisFont;
@property (nonatomic) BXFont* sectionFont;

+ (BeatFonts*)sharedFonts;
+ (BeatFonts*)sharedSansSerifFonts;
+ (CGFloat)characterWidth;

- (NSFont*)withSize:(CGFloat)size;
- (NSFont*)boldWithSize:(CGFloat)size;
@end

NS_ASSUME_NONNULL_END
