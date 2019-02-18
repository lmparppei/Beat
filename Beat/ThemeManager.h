//
//  ThemeManager.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ThemeManager : NSObject

+ (ThemeManager*)sharedManager;

//Access the current theme
- (NSColor*) currentBackgroundColor;
- (NSColor*) currentSelectionColor;
- (NSColor*) currentTextColor;
- (NSColor*) currentInvisibleTextColor;
- (NSColor*) currentCaretColor;
- (NSColor*) currentCommentColor;
- (NSColor*) currentMarginColor;

- (NSUInteger)numberOfThemes;
- (NSString*)nameForThemeAtIndex:(NSUInteger)index;
- (NSUInteger)selectedTheme;
- (void)selectThemeWithName:(NSString*)name;

@end
