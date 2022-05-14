/*
 
 Original code © Paulo Andrade
 Modified for Beat iOS by Lauri-Matti Parppei
 
 No license information available, so I'm guessing this is public domain
 
 NOTE: THIS IS THE iOS VERSION OF DYNAMIC COLOR
 
 */

#import <UIKit/UIKit.h>
#import "iOSDynamicColor.h"

#define FORWARD( PROP, TYPE ) \
- (TYPE)PROP { return [self.effectiveColor PROP]; }

@interface DynamicColor ()
@property (nonatomic, strong, readonly) UIColor *effectiveColor;
@end

@implementation DynamicColor

- (instancetype)initWithAquaColor:(UIColor *)aquaColor
                    darkAquaColor:(UIColor *)darkAquaColor
{
    self = [super init];
    if (self) {
        _aquaColor = aquaColor;
        _darkAquaColor = darkAquaColor;
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _aquaColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"aquaColor"];
        _darkAquaColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"darkAquaColor"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.aquaColor forKey:@"aquaColor"];
    if (self.darkAquaColor) {
        [aCoder encodeObject:self.darkAquaColor forKey:@"darkAquaColor"];
    }
}

- (UIColor *)effectiveColor
{
	// Don't allow calls to this class from anywhere else than main thread
	if (!NSThread.isMainThread) return self.aquaColor;
	
	if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) return self.darkAquaColor;
	else return self.aquaColor;
}

- (UIColor *)effectiveColorFor:(UIView*)view
{
	// Don't allow calls to this class from anywhere else than main thread
	if (!NSThread.isMainThread) return self.aquaColor;
	
	if (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) return self.darkAquaColor;
	else return self.aquaColor;
}



#pragma mark - RGB colorspace

- (bool)getRed:(nullable CGFloat *)red green:(nullable CGFloat *)green blue:(nullable CGFloat *)blue alpha:(nullable CGFloat *)alpha
{
    return [self.effectiveColor getRed:red green:green blue:blue alpha:alpha];
}


#pragma mark - Others

FORWARD(CGColor, CGColorRef)

-(NSUInteger)hash {
    return [super hash];
}

- (void)setStroke
{
     [self.effectiveColor setStroke];
}

- (void)setFill
{
    [self.effectiveColor setFill];
}

- (void)set
{
    [self.effectiveColor set];
}

- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha
{
    return [self.effectiveColor colorWithAlphaComponent:alpha];
}

- (BOOL)isEqualToColor:(DynamicColor *)otherColor {
	CGColorSpaceRef colorSpaceRGB = CGColorSpaceCreateDeviceRGB();
	
	UIColor *(^convertColorToRGBSpace)(UIColor*) = ^(UIColor *color) {
		if (CGColorSpaceGetModel(CGColorGetColorSpace(color.CGColor)) == kCGColorSpaceModelMonochrome) {
			const CGFloat *oldComponents = CGColorGetComponents(color.CGColor);
			CGFloat components[4] = {oldComponents[0], oldComponents[0], oldComponents[0], oldComponents[1]};
			CGColorRef colorRef = CGColorCreate( colorSpaceRGB, components );

			UIColor *color = [UIColor colorWithCGColor:colorRef];
			CGColorRelease(colorRef);
			return color;
		} else
			return color;
	};
	
	UIColor *lightColor = convertColorToRGBSpace(self.aquaColor);
	UIColor *darkColor = convertColorToRGBSpace(self.darkAquaColor);
	
	UIColor *lightOther = convertColorToRGBSpace(otherColor.aquaColor);
	UIColor *darkOther = convertColorToRGBSpace(otherColor.darkAquaColor);
	
	CGColorSpaceRelease(colorSpaceRGB);
	
	if ([lightColor isEqual:lightOther] && [darkColor isEqual:darkOther]) return YES;
	else return NO;
}

- (NSArray*)valuesAsRGB {
	UIColor *light = [self convertToRGB:self.aquaColor];
	UIColor *dark = [self convertToRGB:self.darkAquaColor];
	
    CGFloat lRed, lBlue, lGreen, dRed, dBlue, dGreen;
    [light getRed:&lRed green:&lGreen blue:&lBlue alpha:nil];
    [dark getRed:&dRed green:&dGreen blue:&dBlue alpha:nil];
    
	NSArray *result = @[
		@[ [NSNumber numberWithInt:(lRed * 255)], [NSNumber numberWithInt:(lGreen * 255)], [NSNumber numberWithInt:(lBlue * 255)] ],
		@[ [NSNumber numberWithInt:(dRed * 255)], [NSNumber numberWithInt:(dGreen * 255)], [NSNumber numberWithInt:(dBlue * 255)] ]
	];
	
	return result;
}

- (UIColor*)convertToRGB:(UIColor*)color {
	if (CGColorSpaceGetModel(CGColorGetColorSpace(color.CGColor)) == kCGColorSpaceModelMonochrome) {
		CGColorSpaceRef colorSpaceRGB = CGColorSpaceCreateDeviceRGB();
		
		const CGFloat *oldComponents = CGColorGetComponents(color.CGColor);
		CGFloat components[4] = {oldComponents[0], oldComponents[0], oldComponents[0], oldComponents[1]};
		CGColorRef colorRef = CGColorCreate( colorSpaceRGB, components );

		UIColor *color = [UIColor colorWithCGColor:colorRef];
		CGColorRelease(colorRef);
		CGColorSpaceRelease(colorSpaceRGB);
		return color;
	} else
		return color;
}

@end
