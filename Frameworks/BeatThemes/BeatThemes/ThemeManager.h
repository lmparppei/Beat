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
#endif

//#import "BeatTheme.h"

@class BeatTheme;
@class DynamicColor;

@protocol BeatThemeDelegate
- (NSURL*)appDataPath:(NSString*)path;
@end
@protocol BeatThemeManagedDocument
- (void)updateTheme;
@end


@interface ThemeManager : NSObject

@property (nonatomic) BeatTheme* theme;

+ (ThemeManager*)sharedManager;

/// Returns the default theme.
- (BeatTheme*)defaultTheme;
/// Turns a property list into a theme.
- (BeatTheme*)dictionaryToTheme:(NSDictionary*)values;
/// Loads default and saved custom themes and applies them
- (void)revertToSaved;
/// Read a single, preprocessed theme
// - (void)readTheme:(BeatTheme*)theme;
/// Reloads the UI for each open document.
- (void)loadThemeForAllDocuments;
/// Resets themes to bundled default, removing any user customization.
- (void)resetToDefault;
/// Saves the current theme in user directory.
- (void)saveTheme;

//Access the current theme
- (BeatTheme*) theme;

#pragma mark - Shorthands

@property (nonatomic) DynamicColor* backgroundColor;
@property (nonatomic) DynamicColor* marginColor;
@property (nonatomic) DynamicColor* selectionColor;
@property (nonatomic) DynamicColor* textColor;
@property (nonatomic) DynamicColor* invisibleTextColor;
@property (nonatomic) DynamicColor* caretColor;
@property (nonatomic) DynamicColor* commentColor;
@property (nonatomic) DynamicColor* pageNumberColor;
@property (nonatomic) DynamicColor* sectionTextColor;
@property (nonatomic) DynamicColor* synopsisTextColor;
@property (nonatomic) DynamicColor* highlightColor;
@property (nonatomic) DynamicColor* macroColor;
@property (nonatomic) DynamicColor* genderWomanColor;
@property (nonatomic) DynamicColor* genderManColor;
@property (nonatomic) DynamicColor* genderOtherColor;
@property (nonatomic) DynamicColor* genderUnspecifiedColor;
@property (nonatomic) DynamicColor* outlineHighlight;
@property (nonatomic) DynamicColor* outlineBackground;
@property (nonatomic) DynamicColor* outlineSection;
@property (nonatomic) DynamicColor* outlineItem;
@property (nonatomic) DynamicColor* outlineItemOmitted;
@property (nonatomic) DynamicColor* outlineSceneNumber;
@property (nonatomic) DynamicColor* outlineSynopsis;
@property (nonatomic) DynamicColor* outlineNote;


@end
