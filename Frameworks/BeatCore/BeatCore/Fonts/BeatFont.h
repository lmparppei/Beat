//
//  BeatFont.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 4.6.2023.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#define BXFont UIFont
#else
#import <AppKit/AppKit.h>
#define BXFont NSFont
#endif



NS_ASSUME_NONNULL_BEGIN

@interface BeatFont : NSObject

@property (nonatomic, readonly) BXFont *plain;
@property (nonatomic, readonly) BXFont *bold;
@property (nonatomic, readonly) BXFont *italic;
@property (nonatomic, readonly) BXFont *boldItalic;
@property (nonatomic, readonly) BXFont *emojiFont;

- (instancetype)initWithFontNames:(NSString *)plainFontName
                             bold:(NSString *)boldFontName
                          italic:(NSString *)italicFontName
                      boldItalic:(NSString *)boldItalicFontName
                           emoji:(NSString *)emojiFontName;

@end

NS_ASSUME_NONNULL_END
