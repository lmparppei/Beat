#include <Cocoa/Cocoa.h>

@interface DynamicColor : NSColor

- (instancetype _Nullable )initWithAquaColor:(NSColor *__nonnull)aquaColor
      darkAquaColor:(NSColor *__nullable)darkAquaColor;

- (NSColor *_Nonnull)effectiveColor;

@end
