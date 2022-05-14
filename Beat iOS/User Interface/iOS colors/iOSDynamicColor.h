/*
 
 NOTE: This is the iOS version of the class.
 
 */
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
