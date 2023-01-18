//
//  ThemeManager.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <TargetConditionals.h>
#import <BeatDynamicColor/BeatDynamicColor.h>

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
	#define BXColor UIColor
#else
	#import <Cocoa/Cocoa.h>
	#define BXColor NSColor
#endif

//#import "BeatTheme.h"

@class BeatTheme;

@protocol BeatThemeDelegate
- (NSURL*)appDataPath:(NSString*)path;
@end
@protocol BeatThemeManagedDocument
- (void)updateTheme;
@end


@interface ThemeManager : NSObject

@property (nonatomic) BeatTheme* theme;

+ (ThemeManager*)sharedManager;

- (BeatTheme*)defaultTheme;
- (BeatTheme*)dictionaryToTheme:(NSDictionary*)values;
- (void)revertToSaved; /// Loads default and saved custom themes and applies them
- (void)readTheme:(BeatTheme*)theme; /// Read a single, preprocessed theme
- (void)loadThemeForAllDocuments;
- (void)resetToDefault;
- (void)saveTheme;

//Access the current theme
- (BeatTheme*) theme;

- (DynamicColor*)backgroundColor;
- (DynamicColor*)marginColor;
- (DynamicColor*)selectionColor;
- (DynamicColor*)textColor;
- (DynamicColor*)invisibleTextColor;
- (DynamicColor*)caretColor;
- (DynamicColor*)commentColor;
- (DynamicColor*)pageNumberColor;
- (DynamicColor*)sectionTextColor;
- (DynamicColor*)synopsisTextColor;
- (DynamicColor*)highlightColor;

- (DynamicColor*)genderWomanColor;
- (DynamicColor*)genderManColor;
- (DynamicColor*)genderOtherColor;
- (DynamicColor*)genderUnspecifiedColor;

- (DynamicColor*)outlineHighlight;
- (DynamicColor*)outlineBackground;
- (DynamicColor*)outlineSection;
- (DynamicColor*)outlineItem;
- (DynamicColor*)outlineItemOmitted;
- (DynamicColor*)outlineSceneNumber;
- (DynamicColor*)outlineSynopsis;

@end
