
#import <TargetConditionals.h>

#if TARGET_OS_OSX

// macOS implementation
#import <Cocoa/Cocoa.h>

@protocol BeatDarknessDelegate
- (bool)isDark;
@end

@interface DynamicColor : NSColor <NSCopying>
@property (nonatomic, strong, nonnull) NSColor *aquaColor;
@property (nonatomic, strong, nullable) NSColor *darkAquaColor;

- (instancetype _Nullable )initWithAquaColor:(NSColor *__nonnull)aquaColor
      darkAquaColor:(NSColor *__nullable)darkAquaColor;

- (NSColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor *_Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;

@end

#else

// iOS implementation
#include <UIKit/UIKit.h>

@interface DynamicColor : UIColor
@property (nonatomic, strong, nonnull) UIColor *aquaColor;
@property (nonatomic, strong, nullable) UIColor *darkAquaColor;

- (instancetype _Nullable )initWithAquaColor:(UIColor * _Nonnull)aquaColor darkAquaColor:(UIColor * _Nullable)darkAquaColor;

- (UIColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor * _Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;
- (UIColor *_Nonnull)effectiveColorFor:(UIView* _Nullable)view;

@end


#endif
