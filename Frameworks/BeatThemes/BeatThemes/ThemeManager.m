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
  
 */

#import "ThemeManager.h"

#import <BeatThemes/BeatThemes-Swift.h>
#import <BeatDynamicColor/BeatDynamicColor.h>

//#import "BeatTheme.h"

@interface ThemeManager ()
@property (strong, nonatomic) NSMutableDictionary* themes;
@property (nonatomic) NSUInteger selectedTheme;
@property (nonatomic) BeatTheme* fallbackTheme;
@end

@implementation ThemeManager

#define THEMES_KEY @"themes"
#define USER_THEME_FILE @"Custom Colors.plist"

#define LOADED_KEY @"loadedTheme"
#define DEFAULT_KEY @"Default"
#define CUSTOM_KEY @"Custom"

#if TARGET_OS_IOS
    #define BXApp UIApplication.sharedApplication
#else
    #define BXApp NSApp
#endif

#pragma mark File Loading
+ (ThemeManager*)sharedManager
{
    static ThemeManager* sharedManager;
    if (!sharedManager) {
        sharedManager = ThemeManager.new;
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


#pragma mark - Loading themes

- (NSURL*)themePath
{
#if TARGET_OS_OSX
    // Read user-created theme file
    id<BeatThemeDelegate> delegate = (id<BeatThemeDelegate>)BXApp.delegate;
    return [delegate appDataPath:@""];
#else
    //let searchPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    NSFileManager* fm = NSFileManager.defaultManager;
    NSArray<NSURL*>* urls = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    if (![fm fileExistsAtPath:urls.firstObject.path]) {
        [fm createDirectoryAtPath:urls.firstObject.path withIntermediateDirectories:true attributes:nil error:nil];
    }
    NSURL* url = [urls.firstObject URLByAppendingPathComponent:@"Beat"];
    return url;
#endif
}

-(void)loadThemes
{
	_themes = NSMutableDictionary.new;
	NSDictionary* themes = [self loadThemeFile];
	
	for (NSDictionary* theme in themes[THEMES_KEY]) {
		NSString* name = theme[@"Name"];
		[_themes setValue:theme forKey:name];
	}
}

/// Load both bundled default theme file, as well as the one customized by user.
- (NSDictionary*)loadThemeFile
{
	NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithContentsOfFile:self.bundlePlistFilePath];
    
	NSDictionary *customPlist = [self loadCustomTheme];
	if (customPlist) {
        // If a custom plist file exists, we'll add the theme to "themes" dictionary in our plist
		NSMutableArray *themes = contents[THEMES_KEY];
		[themes addObject:customPlist];
	}
	
	return contents;
}

/// Read user-created theme file into a dictionary
- (NSDictionary*)loadCustomTheme
{
    NSURL* userUrl = self.themePath;
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	NSDictionary *customPlist = [NSDictionary dictionaryWithContentsOfFile:userUrl.path];
	return customPlist;
}

/// Return the **bundled** `plist` file path
- (NSString*)bundlePlistFilePath
{
    NSBundle *bundle = [NSBundle bundleForClass:ThemeManager.class];
    return [bundle pathForResource:@"Themes" ofType:@"plist"];
}

/// Returns the default theme
-(BeatTheme*)defaultTheme
{
    BeatTheme* theme = [self dictionaryToTheme:self.themes[DEFAULT_KEY]];
    return theme;
}


#pragma mark - Reading themes

/// Resets current theme to the default one
-(void)resetToDefault
{
    _theme = [self dictionaryToTheme:self.themes[DEFAULT_KEY]];
}

/// Reverts the theme to its saved state. A more semantic alias of `reloadTheme`.
- (void)revertToSaved
{
    [self reloadTheme];
}

- (void)reloadTheme
{
    [self loadThemes];
    [self readTheme];
    [self loadThemeForAllDocuments];
}

-(BeatTheme*)dictionaryToTheme:(NSDictionary*)values
{
	BeatTheme* theme = BeatTheme.new;
    
	NSDictionary *lightTheme = values[@"Light"];
	NSDictionary *darkTheme = values[@"Dark"];
	
	// Fall back to light theme if no dark settings are available
	if (!darkTheme.count) darkTheme = lightTheme;
	
    NSDictionary* propertyValues = BeatTheme.propertyValues;
    
#if !TARGET_OS_IOS
	// If it's the default color scheme, we'll use native accent colors for certain items
	if (@available(macOS 10.14, *)) {
		theme.selectionColor = [self dynamicColorFromColor:NSColor.controlAccentColor];
	} else {
		// Fallback on earlier versions
		theme.selectionColor = [self dynamicColorFromArray:lightTheme[@"Selection"] darkArray:darkTheme[@"Selection"]];
	}
#endif
	
    for (NSString* key in propertyValues.allKeys) {
        NSString* property = propertyValues[key];
        DynamicColor* color = [self dynamicColorFromArray:lightTheme[property] darkArray:darkTheme[property]];
        [theme setValue:color forKey:key];
    }
	
	return theme;
}

/// Reads the default theme
-(void)readTheme
{
    // Check if we have a default theme selected, OR a custom theme saved. This is a bit convoluted.
    NSString* loadedTheme = [NSUserDefaults.standardUserDefaults stringForKey:LOADED_KEY];
    if (loadedTheme.length == 0) loadedTheme = CUSTOM_KEY;
    
    NSDictionary* themeDict = _themes[loadedTheme];
    [self readTheme:themeDict];
}

/**
 Reads a single, preprocessed theme.
 - Note: Adding new, customizable values to themes could result in null value problems. We'll cross-check existing values against the default theme, and will only use the changed values for our customized theme.
 */
-(void)readTheme:(NSDictionary*)themeDict
{
	// First load DEFAULT theme into memory
    _theme = self.defaultTheme;
	
    if (themeDict) {
        BeatTheme* theme = [self dictionaryToTheme:themeDict];
        
        // Get the property names from that and overwrite those in default theme.
        // This way we'll never end up with null values, as long as the default theme covers all those.
        NSDictionary* propertyToValue = BeatTheme.propertyValues;
        
        // Iterate through property values and if custom theme has the value, override it in our  default theme
        for (NSString *property in propertyToValue) {
            if ([theme valueForKey:property]) [_theme setValue:[theme valueForKey:property] forKey:property];
        }
    }
}

+ (NSString*)loadedThemeKey
{
    return LOADED_KEY;
}

#pragma mark - Saving themes

-(void)saveTheme
{
	BeatTheme* defaultTheme = [self defaultTheme];
	BeatTheme* customTheme = BeatTheme.new;
    NSURL* userUrl = self.themePath;
	
	for (NSString *property in BeatTheme.propertyValues) {
		DynamicColor *currentColor = [self valueForKey:property];
		DynamicColor *defaultColor = [defaultTheme valueForKey:property];
		
		// We won't save colors that are the same as default colors
		if (![currentColor isEqualToColor:defaultColor]) [customTheme setValue:currentColor forKey:property];
	}
	
	// Convert theme values into a dictionary
	NSDictionary *themeDict = [customTheme themeAsDictionaryWithName:CUSTOM_KEY];
	userUrl = [userUrl URLByAppendingPathComponent:USER_THEME_FILE];
	
	[themeDict writeToFile:userUrl.path atomically:NO];
}


#pragma mark - Color conversion

/// Returns a color from an array of doubles: `[r, g, b]`
- (BXColor*)colorFromArray:(NSArray*)array
{
    if (!array || array.count != 3)  return nil;
    
    NSNumber* redValue = array[0];
    NSNumber* greenValue = array[1];
    NSNumber* blueValue = array[2];
    
    double red = redValue.doubleValue / 255.0;
    double green = greenValue.doubleValue / 255.0;
    double blue = blueValue.doubleValue / 255.0;
	
#if TARGET_OS_IOS
	// iOS
	return [BXColor.clearColor initWithRed:red green:green blue:blue alpha:1.0];
#else
	// macOS
	return [BXColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
#endif
}

- (DynamicColor*)dynamicColorFromColor:(BXColor*)color
{
	return [[DynamicColor new] initWithLightColor:color darkColor:color];
}

/// Creates a dynamic color from two arrays using `[r,g,b]` format. Each value is a `NSNumber` double/float.
- (DynamicColor*)dynamicColorFromArray:(NSArray*)lightArray darkArray:(NSArray*)darkArray
{
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

#if TARGET_OS_IOS
	return [[DynamicColor new]
			initWithLightColor:[UIColor.clearColor initWithRed:redLight green:greenLight blue:blueLight alpha:1.0]
			darkColor:[UIColor.clearColor initWithRed:redDark green:greenDark blue:blueDark alpha:1.0]];
#else
	return [[DynamicColor new]
			initWithLightColor:[NSColor colorWithCalibratedRed:redLight green:greenLight blue:blueLight alpha:1.0]
			darkColor:[NSColor colorWithCalibratedRed:redDark green:greenDark blue:blueDark alpha:1.0]];
#endif
}


#pragma mark - Quick access for current theme values

- (BeatTheme*)theme { return _theme; }

- (DynamicColor*)backgroundColor { return _theme.backgroundColor; }
- (DynamicColor*)marginColor { return _theme.marginColor; }
- (DynamicColor*)selectionColor { return _theme.selectionColor; }
- (DynamicColor*)textColor { return _theme.textColor; }
- (DynamicColor*)headingColor { return _theme.headingColor; }
- (DynamicColor*)invisibleTextColor { return _theme.invisibleTextColor; }
- (DynamicColor*)caretColor { return _theme.caretColor; }
- (DynamicColor*)commentColor { return _theme.commentColor; }
- (DynamicColor*)pageNumberColor { return _theme.pageNumberColor; }
- (DynamicColor*)sectionTextColor { return _theme.sectionTextColor; }
- (DynamicColor*)synopsisTextColor { return _theme.synopsisTextColor; }
- (DynamicColor*)highlightColor { return _theme.highlightColor; }

- (DynamicColor*)macroColor { return _theme.macroColor; }

- (DynamicColor*)genderWomanColor { return _theme.genderWomanColor; }
- (DynamicColor*)genderManColor { return _theme.genderManColor; }
- (DynamicColor*)genderOtherColor { return _theme.genderOtherColor; }
- (DynamicColor*)genderUnspecifiedColor { return _theme.genderUnspecifiedColor; }

- (DynamicColor*)outlineHighlight { return _theme.outlineHighlight; }
- (DynamicColor*)outlineBackground { return _theme.outlineBackground; }
- (DynamicColor*)outlineSection { return _theme.outlineSection; }
- (DynamicColor*)outlineItem { return _theme.outlineItem; }
- (DynamicColor*)outlineItemOmitted { return _theme.outlineItemOmitted; }
- (DynamicColor*)outlineNote { return _theme.outlineNote; }
- (DynamicColor*)outlineSceneNumber { return _theme.outlineSceneNumber; }
- (DynamicColor*)outlineSynopsis { return _theme.outlineSynopsis; }


#pragma mark - Load selected theme for ALL documents

- (void)loadThemeForAllDocuments
{
#if !TARGET_OS_IOS
	NSArray* openDocuments = NSApplication.sharedApplication.orderedDocuments;
	
	for (id<BeatThemeManagedDocument>doc in openDocuments) {
		[doc updateTheme];
        [doc reformatAllLines];
	}
#endif
}

@end
