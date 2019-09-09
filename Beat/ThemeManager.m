//
//  ThemeManager.m
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "ThemeManager.h"
#import "Theme.h"

@interface ThemeManager ()
@property (strong, nonatomic) NSMutableArray* themes;
@property (nonatomic) NSUInteger selectedTheme;
@property (nonatomic) NSDictionary* plistContents;

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
		// OMITTED FOR NOW
		
        //If the theme file doesn't exist, copy the default file from the bundle
        // NSFileManager* fileManager = [NSFileManager defaultManager];
		/*
        if (![fileManager fileExistsAtPath:[self plistFilePath]]) {
            [self copyAndLoadOriginalThemeFile];
        } else {
            //If the file exists, but is an older version, copy the default file from the bundle
            NSDictionary *bundlePlistContent = [NSDictionary dictionaryWithContentsOfFile:[self bundlePlistFilePath]];
            _plistContents = [NSDictionary dictionaryWithContentsOfFile:[self plistFilePath]];
            NSUInteger installedVersion = [[_plistContents objectForKey:VERSION_KEY] integerValue];
            NSUInteger bundleVersion = [[bundlePlistContent objectForKey:VERSION_KEY] integerValue];
            
            if (installedVersion < bundleVersion) {
                [self copyAndLoadOriginalThemeFile];
            }
        }
		 
        [self copyAndLoadOriginalThemeFile];
        
        //Try to load the theme file. if it is corrupted, load the original and try again, but this time try to load as much as possible
        if (![self readThemeFile:NO]) {
            [self copyAndLoadOriginalThemeFile];
            [self readThemeFile:YES];
        }
		 */

		[self loadThemeFile];
		if (![self readThemeFile:NO]) {
			[self readThemeFile:YES];
		}
    }
    return self;
}

- (void)loadThemeFile
{
	_plistContents = [NSDictionary dictionaryWithContentsOfFile:[self bundlePlistFilePath]];
}

- (void)copyAndLoadOriginalThemeFile
{
    //Remove any file that might exists
    [[NSFileManager defaultManager] removeItemAtPath:[self plistFilePath]
                                               error:nil];
    //Copy file from bundle
    [[NSFileManager defaultManager] copyItemAtPath:[self bundlePlistFilePath]
                                            toPath:[self plistFilePath]
                                             error:nil];
    _plistContents = [NSDictionary dictionaryWithContentsOfFile:[self plistFilePath]];
}

- (NSString*)plistFilePath
{
    NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                          NSUserDomainMask,
                                                                          YES);
    NSString* applicationSupportDir = searchPaths[0];
    NSString* appName = @"Writer";
    NSString* writerAppSupportDir = [applicationSupportDir stringByAppendingPathComponent:appName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:writerAppSupportDir]) {
        [fileManager createDirectoryAtPath:writerAppSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return [writerAppSupportDir stringByAppendingPathComponent:@"Themes.plist"];
}

- (NSString*)bundlePlistFilePath
{
    return [[NSBundle mainBundle] pathForResource:@"Themes"
                                    ofType:@"plist"];
}

- (BOOL)readThemeFile:(BOOL)continueOnError
{
    //Get the themes
    NSArray* rawThemes = [_plistContents objectForKey:THEMES_KEY];
    if (!rawThemes && !continueOnError) {
        return NO;
    }
    
    self.themes = [[NSMutableArray alloc] initWithCapacity:[rawThemes count]];
    
    for (NSDictionary* dict in rawThemes) {
        Theme* newTheme = [self themeFromDictionary:dict];
        if (newTheme) {
            [self.themes addObject:newTheme];
        } else if (!continueOnError) {
            return NO;
        }
    }
    
    //Get the selected Theme
    self.selectedTheme = [[_plistContents objectForKey:SELECTED_THEME_KEY] integerValue];
    if (self.selectedTheme >= [self numberOfThemes]) {
        if (continueOnError) {
            self.selectedTheme = [self numberOfThemes] == 0 ? 0 : [self numberOfThemes] - 1;
        } else {
            return NO;
        }
    }
    return YES;
}

- (Theme*)themeFromDictionary:(NSDictionary*)dict
{
    Theme* theme = [[Theme alloc] init];
    theme.name = [dict objectForKey:@"Name"];
    if (!theme.name) {
        return nil;
    }
    NSArray* backgroundValues = [dict objectForKey:@"Background"];
    NSArray* selectionValues = [dict objectForKey:@"Selection"];
    NSArray* textValues = [dict objectForKey:@"Text"];
    NSArray* invisibleTextValues = [dict objectForKey:@"InvisibleText"];
    NSArray* caretValues = [dict objectForKey:@"Caret"];
    NSArray* commentValues = [dict objectForKey:@"Comment"];
    NSArray* marginValues = [dict objectForKey:@"Margin"];
    
    theme.backgroundColor = [self colorFromArray:backgroundValues];
    theme.textColor = [self colorFromArray:textValues];
    theme.selectionColor = [self colorFromArray:selectionValues];
    theme.invisibleTextColor = [self colorFromArray:invisibleTextValues];
    theme.caretColor = [self colorFromArray:caretValues];
    theme.commentColor = [self colorFromArray:commentValues];
	theme.marginColor = [self colorFromArray:marginValues];
    
    if (!theme.backgroundColor ||
        !theme.textColor ||
        !theme.selectionColor ||
        !theme.invisibleTextColor ||
        !theme.caretColor ||
        !theme.commentColor) {
        return nil;
    }
    
    return theme;
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

#pragma mark Value Access

- (NSColor*)currentBackgroundColor
{
    return [self currentTheme].backgroundColor;
}

- (NSColor*) currentMarginColor
{
	return [self currentTheme].marginColor;
}

- (NSColor*)currentSelectionColor
{
    return [self currentTheme].selectionColor;
}

- (NSColor*) currentTextColor
{
    return [self currentTheme].textColor;
}

- (NSColor*) currentInvisibleTextColor
{
    return [self currentTheme].invisibleTextColor;
}

- (NSColor*) currentCaretColor
{
    return [self currentTheme].caretColor;
}

- (NSColor*) currentCommentColor
{
    return [self currentTheme].commentColor;
}

- (Theme*)currentTheme {
    if (self.selectedTheme >= [self numberOfThemes]) {
        return self.fallbackTheme;
    }
    return self.themes[self.selectedTheme];
}

- (Theme *)fallbackTheme
{
    if (!_fallbackTheme) {
        _fallbackTheme = [[Theme alloc] init];
        _fallbackTheme.backgroundColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
        _fallbackTheme.selectionColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
        _fallbackTheme.textColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
        _fallbackTheme.invisibleTextColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
        _fallbackTheme.caretColor = [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
        _fallbackTheme.commentColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    }
    return _fallbackTheme;
}



#pragma mark Selection management

- (NSUInteger)numberOfThemes
{
    return [self.themes count];
}

- (NSString*)nameForThemeAtIndex:(NSUInteger)index
{
    if (index >= [self numberOfThemes]) {
        return @"";
    }
    Theme* theme = self.themes[index];
    return theme.name;
}

- (NSUInteger)selectedTheme
{
    return _selectedTheme;
}

- (void)selectThemeWithName:(NSString *)name
{
    for (int i = 0; i < [self numberOfThemes]; i++) {
        Theme *theme = self.themes[i];
        if ([theme.name isEqualToString:name]) {
            self.selectedTheme = i;
            [self.plistContents setValue:@(i) forKey:SELECTED_THEME_KEY];
            NSString* plistFilePath = [self plistFilePath];
            [self.plistContents writeToFile:plistFilePath atomically:YES];
            return;
        }
    }
}

@end
