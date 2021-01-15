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
#import "Theme.h"
#import "DynamicColor.h"

@interface ThemeManager ()
@property (strong, nonatomic) NSMutableArray* themes;
@property (nonatomic) NSUInteger selectedTheme;
@property (nonatomic) NSDictionary* plistContents;
@property (nonatomic) Theme* theme;

@property (strong, nonatomic) Theme* fallbackTheme;
@end

@implementation ThemeManager

#define VERSION_KEY @"version"
#define SELECTED_THEME_KEY @"selectedTheme"
#define THEMES_KEY @"themes"

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
		[self loadThemeFile];
		[self readThemeFile:YES];
    }
    return self;
}

- (void)loadThemeFile
{
	_plistContents = [NSDictionary dictionaryWithContentsOfFile:[self bundlePlistFilePath]];
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

- (BOOL)readThemeFile:(BOOL)continueOnError
{
	[self readTheme];
	return true;
}

-(void)readCustomTheme {
	
}

-(Theme*)loadTheme:(NSDictionary*)values {
	// Work for the new theme model
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:values];
	Theme *theme = [[Theme alloc] init];
	
	NSArray *keys = @[@"Background", @"Margin", @"Selection", @"Text", @"InvisibleText", @"Caret", @"Comment", @"OutlineBackground", @"OutlineHighlight"];
	for (NSString *key in keys) {
		NSString *light = [NSString stringWithFormat:@"%@ Light", key];
		NSString *dark = [NSString stringWithFormat:@"%@ Dark", key];
		if (!dict[dark]) dict[dark] = dict[light];
	}
	
	theme.backgroundColor = [self dynamicColorFromArray:values[@"Background Light"] darkArray:values[@"Background Dark"]];
	theme.textColor = [self dynamicColorFromArray:values[@"Text Light"] darkArray:values[@"Text Dark"]];
	theme.marginColor = [self dynamicColorFromArray:values[@"Margin Light"] darkArray:values[@"Margin Dark"]];
	theme.marginColor = [self dynamicColorFromArray:values[@"Margin Light"] darkArray:values[@"Margin Dark"]];
	theme.selectionColor = [self dynamicColorFromArray:values[@"Selection Light"] darkArray:values[@"Selection Dark"]];
	theme.commentColor  = [self dynamicColorFromArray:values[@"Comment Light"] darkArray:values[@"Comment Dark"]];
	theme.commentColor  = [self dynamicColorFromArray:values[@"InvisibleText Light"] darkArray:values[@"InvisibleText Dark"]];
	theme.caretColor = [self dynamicColorFromArray:values[@"Caret Light"] darkArray:values[@"Caret Dark"]];
	
	theme.outlineBackground = [self dynamicColorFromArray:values[@"OutlineBackground Light"] darkArray:values[@"OutlineBackground Dark"]];
	theme.outlineHighlight = [self dynamicColorFromArray:values[@"OutlineHighlight Light"] darkArray:values[@"OutlineHighlight Dark"]];
	
	return theme;
}


-(void)readTheme {
	Theme* theme = [[Theme alloc] init];
	NSArray* themes = [_plistContents objectForKey:THEMES_KEY];
	
	NSArray* backgroundValuesLight = [[themes objectAtIndex:0] objectForKey:@"Background"];
	NSArray* backgroundValuesDark = [[themes objectAtIndex:1] objectForKey:@"Background"];
	
	NSArray* marginValuesLight = [[themes objectAtIndex:0] objectForKey:@"Margin"];
	NSArray* marginValuesDark = [[themes objectAtIndex:1] objectForKey:@"Margin"];
	
	NSArray* selectionValuesLight = [[themes objectAtIndex:0] objectForKey:@"Selection"];
	NSArray* selectionValuesDark = [[themes objectAtIndex:1] objectForKey:@"Selection"];
	
	NSArray* textValuesLight = [[themes objectAtIndex:0] objectForKey:@"Text"];
	NSArray* textValuesDark = [[themes objectAtIndex:1] objectForKey:@"Text"];
	
	NSArray* invisibleTextValuesLight = [[themes objectAtIndex:0] objectForKey:@"InvisibleText"];
	NSArray* invisibleTextValuesDark = [[themes objectAtIndex:1] objectForKey:@"InvisibleText"];
	
	NSArray* caretValuesLight = [[themes objectAtIndex:0] objectForKey:@"Caret"];
	NSArray* caretValuesDark = [[themes objectAtIndex:1] objectForKey:@"Caret"];
	
	NSArray* commentValuesLight =  [[themes objectAtIndex:0] objectForKey:@"Comment"];
	NSArray* commentValuesDark =  [[themes objectAtIndex:1] objectForKey:@"Comment"];

	NSArray* outlineBackgroundLight =  [[themes objectAtIndex:0] objectForKey:@"OutlineBackground"];
	NSArray* outlineBackgroundDark =  [[themes objectAtIndex:1] objectForKey:@"OutlineBackground"];
	
	NSArray* outlineHighlightLight =  [[themes objectAtIndex:0] objectForKey:@"OutlineHighlight"];
	NSArray* outlineHighlightDark =  [[themes objectAtIndex:1] objectForKey:@"OutlineHighlight"];

	theme.backgroundColor = [self dynamicColorFromArray:backgroundValuesLight darkArray:backgroundValuesDark];
	theme.textColor = [self dynamicColorFromArray:textValuesLight darkArray:textValuesDark];
	theme.selectionColor = [self dynamicColorFromArray:selectionValuesLight darkArray:selectionValuesDark];
	theme.invisibleTextColor = [self dynamicColorFromArray:invisibleTextValuesLight darkArray:invisibleTextValuesDark];
	theme.caretColor = [self dynamicColorFromArray:caretValuesLight darkArray:caretValuesDark];
	theme.commentColor = [self dynamicColorFromArray:commentValuesLight darkArray:commentValuesDark];
	theme.marginColor = [self dynamicColorFromArray:marginValuesLight darkArray:marginValuesDark];

	// Outline settings
	theme.outlineBackground = [self dynamicColorFromArray:outlineBackgroundLight darkArray:outlineBackgroundDark];
	theme.outlineHighlight =  [self dynamicColorFromArray:outlineHighlightLight darkArray:outlineHighlightDark];
	
	_theme = theme;
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

@end
