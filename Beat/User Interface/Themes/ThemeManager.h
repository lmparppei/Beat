//
//  ThemeManager.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
	#define BXColor UIColor
#else
	#import <Cocoa/Cocoa.h>
	#define BXColor NSColor
	#import "ThemeEditor.h"
#endif

#import "DynamicColor.h"
#import "BeatTheme.h"

@protocol BeatTheme;
@interface ThemeManager : NSObject

#if !TARGET_OS_IOS
@property (nonatomic) ThemeEditor *themeEditor;
#endif

@property (nonatomic) id<BeatTheme> theme;

+ (ThemeManager*)sharedManager;

- (void)showEditor;

- (id<BeatTheme>)defaultTheme;
- (id<BeatTheme>)dictionaryToTheme:(NSDictionary*)values;
- (void)revertToSaved; /// Loads default and saved custom themes and applies them
- (void)readTheme:(id<BeatTheme>)theme; /// Read a single, preprocessed theme
- (void)loadThemeForAllDocuments;
- (void)resetToDefault;
- (void)saveTheme;

//Access the current theme
- (id<BeatTheme>) theme;

- (DynamicColor*)currentBackgroundColor;
- (DynamicColor*)currentSelectionColor;
- (DynamicColor*)currentTextColor;
- (DynamicColor*)currentInvisibleTextColor;
- (DynamicColor*)currentCaretColor;
- (DynamicColor*)currentCommentColor;
- (DynamicColor*)currentMarginColor;
- (DynamicColor*)currentOutlineBackground;
- (DynamicColor*)currentOutlineHighlight;
- (DynamicColor*)currentHighlightColor;

- (DynamicColor*)backgroundColor;
- (DynamicColor*)marginColor;
- (DynamicColor*)selectionColor;
- (DynamicColor*)textColor;
- (DynamicColor*)invisibleTextColor;
- (DynamicColor*)caretColor;
- (DynamicColor*)commentColor;
- (DynamicColor*)outlineHighlight;
- (DynamicColor*)outlineBackground;
- (DynamicColor*)pageNumberColor;
- (DynamicColor*)sectionTextColor;
- (DynamicColor*)synopsisTextColor;
- (DynamicColor*)highlightColor;

- (DynamicColor*)genderWomanColor;
- (DynamicColor*)genderManColor;
- (DynamicColor*)genderOtherColor;
- (DynamicColor*)genderUnspecifiedColor;

@end
