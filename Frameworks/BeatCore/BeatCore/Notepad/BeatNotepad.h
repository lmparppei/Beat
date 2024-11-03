//
//  BeatNotepad.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 15.8.2024.
//

#import <Foundation/Foundation.h>
#import <BeatCore/BeatEditorDelegate.h>
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/NSTextView+UX.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class DynamicColor;

@protocol BeatNotepadExports <JSExport>
@property (nonatomic) NSString* string;
@property (nonatomic) NSString* text;
@property (nonatomic) bool observerDisabled;
@property (nonatomic) NSRange selectedRange;
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)position length:(NSInteger)length string:(NSString*)string color:(NSString*)colorName);
@end

@interface BeatNotepad : BXTextView <BeatNotepadExports>
@property (weak, nonatomic) IBOutlet id<BeatEditorDelegate> editorDelegate;
@property (nonatomic) bool observerDisabled;

@property (nonatomic) DynamicColor* defaultColor;
@property (nonatomic) NSString *currentColorName;
@property (nonatomic) BXColor *currentColor;
#if TARGET_OS_IOS
@property (nonatomic) NSString* string;
#endif

@property (nonatomic) IBInspectable CGFloat baseFontSize;

- (void)setup;
- (void)loadString:(NSString*)string;

/// Sets the current input color
- (void)setColor:(NSString*)colorName;

- (void)replaceRange:(NSInteger)position length:(NSInteger)length string:(NSString*)string color:(NSString*)colorName;

- (void)saveToDocument;
- (NSString*)stringForSaving;
- (NSAttributedString*)coloredRanges:(NSString*)fullString;


@end

NS_ASSUME_NONNULL_END
