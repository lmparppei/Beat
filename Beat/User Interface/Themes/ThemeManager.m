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
 This should be rewritten to support multiple themes again, or at least one local custom theme.
 Either save it to user preferences or in Application Support folder.
 
 The plist could be modified as so:
 "Default": { color: [light, dark], color: [light, dark] }
 
 This way the user-made plist or NSUserDefault could be loaded using the same method, with
 the dict containing both light and dark mode values.
 
 */

#import "ThemeManager.h"
#import "ThemeEditor.h"
#import "Theme.h"
#import "DynamicColor.h"
#import "ApplicationDelegate.h"
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

- (void)loadThemeFile
{
	NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithContentsOfFile:[self bundlePlistFilePath]];
		
	// Read user-created theme file
	NSURL *userUrl = [(ApplicationDelegate*)NSApp.delegate appDataPath:@""];
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	NSDictionary *customPlist = [NSDictionary dictionaryWithContentsOfFile:userUrl.path];
	if (customPlist) {
		NSDictionary *themes = contents[THEMES_KEY];
		[themes setValue:customPlist forKey:CUSTOM_KEY];
	}
	
	_plistContents = contents;
}

- (void)saveCustomTheme
{
	NSURL *userUrl = [(ApplicationDelegate*)NSApp.delegate appDataPath:@""];
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	NSDictionary *customTheme = _themes[@"Custom"];
	if (!customTheme) customTheme = [NSDictionary dictionary];
	
	[customTheme writeToFile:userUrl.path atomically:NO];
}

/*
- (NSString*)plistFilePath
{
    NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                          NSUserDomainMask,
                                                                          YES);
    NSString* applicationSupportDir = searchPaths[0];
    NSString* appName = @"Beat";
    NSString* writerAppSupportDir = [applicationSupportDir stringByAppendingPathComponent:appName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:writerAppSupportDir]) {
        [fileManager createDirectoryAtPath:writerAppSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return [writerAppSupportDir stringByAppendingPathComponent:@"Themes.plist"];
}
*/

- (NSString*)bundlePlistFilePath
{
    return [[NSBundle mainBundle] pathForResource:@"Themes"
                                    ofType:@"plist"];
}

-(void)readCustomTheme {
	
}
-(Theme*)defaultTheme {
	Theme *theme = [self loadTheme:self.themes[DEFAULT_KEY]];
	return theme;
}
-(void)resetToDefault {
	_theme = [self loadTheme:self.themes[DEFAULT_KEY]];
}

-(Theme*)loadTheme:(NSDictionary*)values {
	// Work for the new theme model
	Theme *theme = [[Theme alloc] init];

	NSDictionary *lightTheme = values[@"Light"];
	NSDictionary *darkTheme = values[@"Dark"];
	
	// Fall back to light theme if no dark settings are available
	if (!darkTheme.count) darkTheme = lightTheme;
	
	theme.backgroundColor = [self dynamicColorFromArray:lightTheme[@"Background"] darkArray:darkTheme[@"Background"]];
	theme.textColor = [self dynamicColorFromArray:lightTheme[@"Text"] darkArray:darkTheme[@"Text"]];
	theme.marginColor = [self dynamicColorFromArray:lightTheme[@"Margin"] darkArray:darkTheme[@"Margin"]];
	theme.selectionColor = [self dynamicColorFromArray:lightTheme[@"Selection"] darkArray:darkTheme[@"Selection"]];
	theme.commentColor  = [self dynamicColorFromArray:lightTheme[@"Comment"] darkArray:darkTheme[@"Comment"]];
	theme.invisibleTextColor  = [self dynamicColorFromArray:lightTheme[@"InvisibleText"] darkArray:darkTheme[@"InvisibleText"]];
	theme.caretColor = [self dynamicColorFromArray:lightTheme[@"Caret"] darkArray:darkTheme[@"Caret"]];
	theme.pageNumberColor = [self dynamicColorFromArray:lightTheme[@"PageNumber"] darkArray:darkTheme[@"PageNumber"]];
	
	theme.synopsisTextColor = [self dynamicColorFromArray:lightTheme[@"SynopsisText"] darkArray:darkTheme[@"SynopsisText"]];
	theme.sectionTextColor = [self dynamicColorFromArray:lightTheme[@"SectionText"] darkArray:darkTheme[@"SectionText"]];
	
	theme.outlineBackground = [self dynamicColorFromArray:darkTheme[@"OutlineBackground"] darkArray:darkTheme[@"OutlineBackground"]];
	theme.outlineHighlight = [self dynamicColorFromArray:darkTheme[@"OutlineHighlight"] darkArray:darkTheme[@"OutlineHighlight"]];
	NSLog(@"outlineh %@", theme.outlineHighlight);
	
	return theme;
}


-(void)readTheme {
	// If there is a customized color scheme, apply it
	if (_themes[CUSTOM_KEY]) {
		_theme = [self loadTheme:_themes[CUSTOM_KEY]];
	} else {
		_theme = [self loadTheme:_themes[DEFAULT_KEY]];
	}
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

- (DynamicColor*)dynamicColorFromArray:(NSArray*)lightArray darkArray:(NSArray*)darkArray {
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


- (DynamicColor*)currentBackgroundColor
{
	return _theme.backgroundColor;
}

- (DynamicColor*) currentMarginColor
{
	return _theme.marginColor;
}

- (DynamicColor*)currentSelectionColor
{
	return _theme.selectionColor;
}

- (DynamicColor*) currentTextColor
{
	return _theme.textColor;
}

- (DynamicColor*) currentInvisibleTextColor
{
	return _theme.invisibleTextColor;
}

- (DynamicColor*) currentCaretColor
{
	return _theme.caretColor;
}

- (DynamicColor*) currentCommentColor
{
	return _theme.commentColor;
}

- (Theme*)currentTheme {
	return _theme;
}

- (DynamicColor*)currentOutlineHighlight
{
	return _theme.outlineHighlight;
}

- (DynamicColor*)currentOutlineBackground
{
	return _theme.outlineBackground;
}

- (DynamicColor*)currentPageNumberColor
{
	return _theme.pageNumberColor;
}

#pragma mark - Show Editor

- (void)showEditor {
	if (!self.themeEditor) {
		_themeEditor = [[ThemeEditor alloc] init];
	}
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
