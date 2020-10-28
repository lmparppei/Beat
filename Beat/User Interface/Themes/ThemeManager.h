//
//  ThemeManager.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"
#import "Theme.h"

@interface ThemeManager : NSObject

+ (ThemeManager*)sharedManager;

//Access the current theme
- (Theme*) theme;
- (DynamicColor*) currentBackgroundColor;
- (DynamicColor*) currentSelectionColor;
- (DynamicColor*) currentTextColor;
- (DynamicColor*) currentInvisibleTextColor;
- (DynamicColor*) currentCaretColor;
- (DynamicColor*) currentCommentColor;
- (DynamicColor*) currentMarginColor;
- (DynamicColor*) currentOutlineBackground;
- (DynamicColor*) currentOutlineHighlight;

@end
