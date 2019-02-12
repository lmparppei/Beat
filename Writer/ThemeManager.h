//
//  ThemeManager.h
//  Writer
//
//  Created by Hendrik Noeller on 04.04.16.
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

- (NSUInteger)numberOfThemes;
- (NSString*)nameForThemeAtIndex:(NSUInteger)index;
- (NSUInteger)selectedTheme;
- (void)selectThemeWithName:(NSString*)name;

@end
