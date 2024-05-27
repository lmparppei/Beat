
#import <TargetConditionals.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol DynamicColorExports <JSExport>
- (NSString*_Nullable)cssRGB;
@end

#if TARGET_OS_OSX

// macOS implementation
#import <Cocoa/Cocoa.h>

@protocol BeatDarknessDelegate
- (bool)isDark;
@end

@interface DynamicColor : NSColor <NSCopying, DynamicColorExports>
@property (nonatomic, strong, nonnull) NSColor *lightColor;
@property (nonatomic, strong, nullable) NSColor *darkColor;

- (instancetype _Nullable )initWithLightColor:(NSColor *__nonnull)lightColor
      darkColor:(NSColor *__nullable)darkColor;

- (NSColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor *_Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;
- (NSString*_Nullable)cssRGB;

@end

#else

// iOS implementation
#include <UIKit/UIKit.h>

@interface DynamicColor : UIColor <DynamicColorExports>
@property (nonatomic, strong, nonnull) UIColor *lightColor;
@property (nonatomic, strong, nullable) UIColor *darkColor;

- (instancetype _Nullable )initWithLightColor:(UIColor * _Nonnull)lightColor darkColor:(UIColor * _Nullable)darkColor;

- (UIColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor * _Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;
- (UIColor *_Nonnull)effectiveColorFor:(UIView* _Nullable)view;
- (NSString*_Nullable)cssRGB;

@end


#endif
