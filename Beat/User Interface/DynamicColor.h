#include <Cocoa/Cocoa.h>

@interface DynamicColor : NSColor
@property (nonatomic, strong, nonnull) NSColor *aquaColor;
@property (nonatomic, strong, nullable) NSColor *darkAquaColor;

- (instancetype _Nullable )initWithAquaColor:(NSColor *__nonnull)aquaColor
      darkAquaColor:(NSColor *__nullable)darkAquaColor;

- (NSColor *_Nonnull)effectiveColor;

- (BOOL)isEqualToColor:(DynamicColor *_Nonnull)otherColor;
- (NSArray*_Nonnull)valuesAsRGB;

@end
