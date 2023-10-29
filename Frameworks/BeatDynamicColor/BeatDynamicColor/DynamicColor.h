
#import <TargetConditionals.h>

#if TARGET_OS_OSX

// macOS implementation
#import <Cocoa/Cocoa.h>

@protocol BeatDarknessDelegate
- (bool)isDark;
@end

@interface DynamicColor : NSColor <NSCopying>
@property (nonatomic, strong, nonnull) NSColor *lightColor;
@property (nonatomic, strong, nullable) NSColor *darkColor;

- (instancetype _Nullable )initWithLightColor:(NSColor *__nonnull)lightColor
      darkColor:(NSColor *__nullable)darkColor;

- (NSColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor *_Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;

@end

#else

// iOS implementation
#include <UIKit/UIKit.h>

@interface DynamicColor : UIColor
@property (nonatomic, strong, nonnull) UIColor *lightColor;
@property (nonatomic, strong, nullable) UIColor *darkColor;

- (instancetype _Nullable )initWithLightColor:(UIColor * _Nonnull)lightColor darkColor:(UIColor * _Nullable)darkColor;

- (UIColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor * _Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;
- (UIColor *_Nonnull)effectiveColorFor:(UIView* _Nullable)view;

@end


#endif
