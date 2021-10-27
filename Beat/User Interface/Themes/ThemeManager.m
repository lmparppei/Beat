//
//  ThemeManager.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Parts copyright © 2016 Hendrik Noeller. All rights reserved.
//

/*
 
 NOTE:
 This has been rewritten to support macOS dark mode and to NOT support multiple themes.
 
 NOTE IN 2021:
 This has been rewritten to offer limited support for multiple themes.
 
 NOTE LATER IN 2021:
 Themes.plist file contains two keys: "Default" and "Custom". Both are dictionaries
 with theme values, and loadTheme: converts the dictionary to a Theme object.
 
 Basic usage:
 Theme* theme = [self loadTheme:dictionary];
 [self readTheme:theme];
 
 */

#import "ThemeManager.h"
#import "ThemeEditor.h"
#import "Theme.h"
#import "DynamicColor.h"
#import "BeatAppDelegate.h"
#import "Document.h"

@interface ThemeManager ()
@property (strong, nonatomic) NSMutableDictionary* themes;
@property (nonatomic) NSUInteger selectedTheme;
@property (nonatomic) NSDictionary* plistContents;
@property (nonatomic) NSDictionary* customPlistContents;

@property (strong, nonatomic) Theme* fallbackTheme;
@end

@implementation ThemeManager

#define VERSION_KEY @"version"
#define SELECTED_THEME_KEY @"selectedTheme"
#define THEMES_KEY @"themes"
#define USER_THEME_FILE @"Custom Colors.plist"

#define DEFAULT_KEY @"Default"
#define CUSTOM_KEY @"Custom"

#pragma mark File Loading

+ (ThemeManager*)sharedManager
{
    static ThemeManager* sharedManager;
    if (!sharedManager) {
        sharedManager = [[ThemeManager alloc] init];
    }
    return sharedManager;
}

- (ThemeManager*)init
{
    self = [super init];
    if (self) {
		[self loadThemes];
		[self readTheme];
    }
    return self;
}
-(void)loadThemes {
	_themes = [NSMutableDictionary dictionary];
	[self loadThemeFile];
	
	for (NSDictionary* theme in self.plistContents[THEMES_KEY]) {
		NSString* name = theme[@"Name"];
		[_themes setValue:theme forKey:name];
	}
}
- (void)revertToSaved {
	[self loadThemes];
	[self readTheme];
	[self loadThemeForAllDocuments];
}

- (void)loadThemeFile
{
	NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithContentsOfFile:[self bundlePlistFilePath]];
		
	// Read user-created theme file
	NSURL *userUrl = [(BeatAppDelegate*)NSApp.delegate appDataPath:@""];
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	NSDictionary *customPlist = [NSDictionary dictionaryWithContentsOfFile:userUrl.path];
	
	if (customPlist) {
		NSMutableArray *themes = contents[THEMES_KEY];
		[themes addObject:customPlist];
	}
	
	_plistContents = contents;
}

- (NSString*)bundlePlistFilePath
{
    return [[NSBundle mainBundle] pathForResource:@"Themes" ofType:@"plist"];
}

-(Theme*)defaultTheme {
	Theme *theme = [self dictionaryToTheme:self.themes[DEFAULT_KEY]];
	return theme;
}
-(void)resetToDefault {
	_theme = [self dictionaryToTheme:self.themes[DEFAULT_KEY]];
}

-(Theme*)dictionaryToTheme:(NSDictionary*)values {
	// Work for the new theme model
	Theme *theme = [[Theme alloc] init];

	NSDictionary *lightTheme = values[@"Light"];
	NSDictionary *darkTheme = values[@"Dark"];
	
	// Fall back to light theme if no dark settings are available
	if (!darkTheme.count) darkTheme = lightTheme;
	
	// If it's the default color scheme, we'll use native accent colors for certain items
	if (@available(macOS 10.14, *)) {
		theme.selectionColor = [self dynamicColorFromColor:NSColor.controlAccentColor];
	} else {
		// Fallback on earlier versions
		theme.selectionColor = [self dynamicColorFromArray:lightTheme[@"Selection"] darkArray:darkTheme[@"Selection"]];
	}

	
	theme.backgroundColor = [self dynamicColorFromArray:lightTheme[@"Background"] darkArray:darkTheme[@"Background"]];
	theme.textColor = [self dynamicColorFromArray:lightTheme[@"Text"] darkArray:darkTheme[@"Text"]];
	theme.marginColor = [self dynamicColorFromArray:lightTheme[@"Margin"] darkArray:darkTheme[@"Margin"]];
	
	theme.commentColor  = [self dynamicColorFromArray:lightTheme[@"Comment"] darkArray:darkTheme[@"Comment"]];
	theme.invisibleTextColor  = [self dynamicColorFromArray:lightTheme[@"InvisibleText"] darkArray:darkTheme[@"InvisibleText"]];
	theme.caretColor = [self dynamicColorFromArray:lightTheme[@"Caret"] darkArray:darkTheme[@"Caret"]];
	theme.pageNumberColor = [self dynamicColorFromArray:lightTheme[@"PageNumber"] darkArray:darkTheme[@"PageNumber"]];

	theme.synopsisTextColor = [self dynamicColorFromArray:lightTheme[@"SynopsisText"] darkArray:darkTheme[@"SynopsisText"]];
	theme.sectionTextColor = [self dynamicColorFromArray:lightTheme[@"SectionText"] darkArray:darkTheme[@"SectionText"]];

	theme.outlineBackground = [self dynamicColorFromArray:darkTheme[@"OutlineBackground"] darkArray:darkTheme[@"OutlineBackground"]];
	theme.outlineHighlight = [self dynamicColorFromArray:darkTheme[@"OutlineHighlight"] darkArray:darkTheme[@"OutlineHighlight"]];
	
	theme.highlightColor = [self dynamicColorFromArray:darkTheme[@"Highlight"] darkArray:darkTheme[@"Highlight"]];
	
	theme.genderWomanColor = [self dynamicColorFromArray:darkTheme[@"Woman"] darkArray:darkTheme[@"Woman"]];
	theme.genderManColor = [self dynamicColorFromArray:darkTheme[@"Man"] darkArray:darkTheme[@"Man"]];
	theme.genderOtherColor = [self dynamicColorFromArray:darkTheme[@"Other"] darkArray:darkTheme[@"Other"]];
	theme.genderUnspecifiedColor = [self dynamicColorFromArray:darkTheme[@"Unspecified"] darkArray:darkTheme[@"Unspecified"]];
	
	return theme;
}

-(void)readTheme:(Theme*)theme {
	/*
	 
	 My reasoning for the following approach is that adding new customizable values could otherwise
	 result in null value problems. Here we cross-check existing values against the default theme,
	 and for customized theme, only the changed values are saved.
	 
	 */
	
	// First load DEFAULT theme into memory
	_theme = [self dictionaryToTheme:_themes[DEFAULT_KEY]];
	
	// Load custom theme (this is a bit convoluted)
	Theme *customTheme = theme;
	
	if (customTheme) {
		// We get the property names from theme, and we'll overwrite those values in default theme
		for (NSString *property in customTheme.propertyToValue) {
			if ([customTheme valueForKey:property]) {
				[_theme setValue:[customTheme valueForKey:property] forKey:property];
			}
		}
	}
}

-(void)readTheme {
	Theme* customTheme = [self dictionaryToTheme:_themes[CUSTOM_KEY]];
	[self readTheme:customTheme];
}

-(void)saveTheme {
	Theme *defaultTheme = [self defaultTheme];
	Theme *customTheme = [[Theme alloc] init];
	
	for (NSString *property in customTheme.propertyToValue) {
		DynamicColor *currentColor = [self valueForKey:property];
		DynamicColor *defaultColor = [defaultTheme valueForKey:property];
		
		// We won't save colors that are the same as default colors
		if (![currentColor isEqualToColor:defaultColor]) [customTheme setValue:currentColor forKey:property];
	}
	
	// Convert theme values into a dictionary
	NSDictionary *themeDict = [customTheme themeAsDictionaryWithName:CUSTOM_KEY];
	
	NSURL *userUrl = [(BeatAppDelegate*)NSApp.delegate appDataPath:@""];
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	[themeDict writeToFile:userUrl.path atomically:NO];
}

- (NSColor*)colorFromArray:(NSArray*)array
{
    if (!array || [array count] != 3) {
        return nil;
    }
    NSNumber* redValue = array[0];
    NSNumber* greenValue = array[1];
    NSNumber* blueValue = array[2];
    
    double red = redValue.doubleValue / 255.0;
    double green = greenValue.doubleValue / 255.0;
    double blue = blueValue.doubleValue / 255.0;
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}

- (DynamicColor*)dynamicColorFromColor:(NSColor*)color {
	return [[DynamicColor new] initWithAquaColor:color darkAquaColor:color];
}

- (DynamicColor*)dynamicColorFromArray:(NSArray*)lightArray darkArray:(NSArray*)darkArray {
	if (!lightArray || !darkArray) return nil;
	
	NSNumber* redValueLight = lightArray[0];
	NSNumber* greenValueLight = lightArray[1];
	NSNumber* blueValueLight = lightArray[2];

	NSNumber* redValueDark = darkArray[0];
	NSNumber* greenValueDark = darkArray[1];
	NSNumber* blueValueDark = darkArray[2];
	
	double redLight = redValueLight.doubleValue / 255.0;
	double greenLight = greenValueLight.doubleValue / 255.0;
	double blueLight = blueValueLight.doubleValue / 255.0;
	
	double redDark = redValueDark.doubleValue / 255.0;
	double greenDark = greenValueDark.doubleValue / 255.0;
	double blueDark = blueValueDark.doubleValue / 255.0;

	return [[DynamicColor new]
			initWithAquaColor:[NSColor colorWithCalibratedRed:redLight green:greenLight blue:blueLight alpha:1.0]
			darkAquaColor:[NSColor colorWithCalibratedRed:redDark green:greenDark blue:blueDark alpha:1.0]];
}

#pragma mark Value Access

- (Theme*)theme {
	return _theme;
}

- (DynamicColor*)backgroundColor { return _theme.backgroundColor; }
- (DynamicColor*)marginColor { return _theme.marginColor; }
- (DynamicColor*)selectionColor { return _theme.selectionColor; }
- (DynamicColor*)textColor { return _theme.textColor; }
- (DynamicColor*)invisibleTextColor { return _theme.invisibleTextColor; }
- (DynamicColor*)caretColor { return _theme.caretColor; }
- (DynamicColor*)commentColor { return _theme.commentColor; }
- (DynamicColor*)outlineHighlight { return _theme.outlineHighlight; }
- (DynamicColor*)outlineBackground { return _theme.outlineBackground; }
- (DynamicColor*)pageNumberColor { return _theme.pageNumberColor; }
- (DynamicColor*)sectionTextColor { return _theme.sectionTextColor; }
- (DynamicColor*)synopsisTextColor { return _theme.synopsisTextColor; }
- (DynamicColor*)highlightColor { return _theme.highlightColor; }

- (DynamicColor*)genderWomanColor { return _theme.genderWomanColor; }
- (DynamicColor*)genderManColor { return _theme.genderManColor; }
- (DynamicColor*)genderOtherColor { return _theme.genderOtherColor; }
- (DynamicColor*)genderUnspecifiedColor { return _theme.genderUnspecifiedColor; }

- (Theme*)currentTheme { return _theme; }
- (DynamicColor*)currentBackgroundColor { return _theme.backgroundColor; }
- (DynamicColor*)currentMarginColor { return _theme.marginColor; }
- (DynamicColor*)currentSelectionColor { return _theme.selectionColor; }
- (DynamicColor*)currentTextColor { return _theme.textColor; }
- (DynamicColor*)currentInvisibleTextColor { return _theme.invisibleTextColor; }
- (DynamicColor*)currentCaretColor { return _theme.caretColor; }
- (DynamicColor*)currentCommentColor {	return _theme.commentColor; }
- (DynamicColor*)currentOutlineHighlight { return _theme.outlineHighlight; }
- (DynamicColor*)currentOutlineBackground { return _theme.outlineBackground; }
- (DynamicColor*)currentPageNumberColor { return _theme.pageNumberColor; }
- (DynamicColor*)currentHighlightColor { return _theme.highlightColor; }

#pragma mark - Show Editor

- (void)showEditor {
	if (!self.themeEditor) _themeEditor = [[ThemeEditor alloc] init];
	[_themeEditor showWindow:_themeEditor.window];
}

#pragma mark - Load selected theme for ALL documents

- (void)loadThemeForAllDocuments
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	
	for (Document* doc in openDocuments) {
		[doc updateTheme];
	}
}

@end
