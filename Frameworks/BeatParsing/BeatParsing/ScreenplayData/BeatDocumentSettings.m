//
//  BeatDocumentSettings.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This creates a settings string that can be saved at the end of a Fountain file.
 I recommend using typed setters & getters when possible.
 
 */

#import "BeatDocumentSettings.h"

#define JSON_MARKER @"\n\n/* If you're seeing this, you can remove the following stuff - BEAT:"
#define JSON_MARKER_END @"END_BEAT */"

@implementation BeatDocumentSettings

NSString * const DocSettingRevisions = @"Revision";
NSString * const DocSettingHiddenRevisions = @"Hidden Revisions";
NSString * const DocSettingRevisionColor = @"Revision Color";
NSString * const DocSettingRevisionLevel = @"Revision Level";
NSString * const DocSettingSceneNumberStart = @"Scene Numbering Starts From";
NSString * const DocSettingTagDefinitions = @"TagDefinitions";
NSString * const DocSettingTags = @"Tags";
NSString * const DocSettingLocked = @"Locked";
NSString * const DocSettingRevisedPageColor = @"Revised Page Color";
NSString * const DocSettingRevisionMode = @"Revision Mode";
NSString * const DocSettingColorCodePages = @"Color-code Pages";
NSString * const DocSettingCaretPosition = @"Caret Position";
NSString * const DocSettingChangedIndices = @"Changed Indices";
NSString * const DocSettingReviews = @"Review Ranges";
NSString * const DocSettingSidebarVisible = @"Sidebar Visible";
NSString * const DocSettingSidebarWidth = @"Sidebar Width";

NSString * const DocSettingHeadingUUIDs = @"Heading UUIDs";
NSString * const DocSettingHeader = @"headerString";
NSString * const DocSettingHeaderAlignment = @"headerAlignment";

NSString * const DocSettingWindowWidth = @"Window Width";
NSString * const DocSettingWindowHeight = @"Window Height";

NSString * const DocSettingActivePlugins = @"Active Plugins";

NSString * const DocSettingPageSize = @"Page Size";

NSString * const DocSettingCharacterGenders = @"CharacterGenders"; // Backwards compatibility
NSString * const DocSettingCharacterData = @"CharacterData";

NSString * const DocSettingPrintSceneNumbers = @"Print Scene Numbers";
NSString * const DocSettingPrintSynopsis = @"Print Synopsis";
NSString * const DocSettingPrintSections = @"Print Sections";
NSString * const DocSettingPrintNotes    = @"Print Notes";

NSString * const DocSettingStylesheet    = @"Stylesheet";

NSString * const DocSettingNovelLineHeightMultiplier = @"novelLineHeightMultiplier"; // Why isn't this key in line with the others?
NSString * const DocSettingContentAlignment = @"novelContentAlignment";

NSString * const DocSettingFirstPageNumber = @"firstPageNumber";
NSString * const DocSettingPageNumberingMode = @"pageNumberingMode";

-(id)init
{
    return [BeatDocumentSettings.alloc initWithDelegate:nil];
}

-(id)initWithDelegate:(id<BeatDocumentSettingDelegate>)delegate
{
    self = [super init];
    if (self) {
        _settings = NSMutableDictionary.new;
        _delegate = delegate;
    }
    return self;
}

+ (NSDictionary*)defaultValues
{
    static NSDictionary* defaultValues;
    if (defaultValues != nil) return defaultValues;
    
    defaultValues = @{
        DocSettingStylesheet: @"Screenplay",
        DocSettingNovelLineHeightMultiplier: @(2.0),
        DocSettingHeaderAlignment: @(1),
        DocSettingPrintSceneNumbers: @(true),
        DocSettingContentAlignment: @"",
        DocSettingFirstPageNumber: @(1),
        DocSettingPageNumberingMode: @(0)
    };
    
    return defaultValues;
}

/// An alias for `+ defaultValues` because of some weird Swift compatibility issues
- (NSDictionary*)defaultValues { return BeatDocumentSettings.defaultValues; }

+ (NSDictionary*)defaultValue:(NSString*)key
{
    return BeatDocumentSettings.defaultValues[key];
}

- (bool)has:(NSString*)key {
    return (_settings[key] != nil);
}


#pragma mark - Setters

- (void)toggleBool:(NSString*)key
{
    bool value = [self getBool:key];
    [self setBool:key as:!value];
}
- (void)setBool:(NSString*)key as:(bool)value { [self set:key as:@(value)]; }
- (void)setInt:(NSString*)key as:(NSInteger)value { [self set:key as:@(value)]; }
- (void)setFloat:(NSString*)key as:(CGFloat)value { [self set:key as:@(value)]; }
- (void)setString:(NSString*)key as:(NSString*)value { [self set:key as:value]; }
- (void)set:(NSString*)key as:(id)value
{
	[_settings setValue:value forKey:key];
    [_delegate addToChangeCount];
}


#pragma mark - Getters

- (NSInteger)getInt:(NSString *)key { return ((NSNumber*)[self get:key]).integerValue; }
- (CGFloat)getFloat:(NSString *)key { return ((NSNumber*)[self get:key]).floatValue; }
- (bool)getBool:(NSString *)key { return ((NSNumber*)[self get:key]).boolValue; }
- (NSString*)getString:(NSString *) key
{
    NSString *value = (NSString*)[self get:key];
	if (![value isKindOfClass:NSString.class]) value = @"";
    return (value != nil) ? value : @"";
}

- (id)get:(NSString*)key
{
    id value = _settings[key];
    
    // If no value is set, try to get default value. It might be null too.
    if (value == nil) value = BeatDocumentSettings.defaultValues[key];
    
	return value;
}


#pragma mark - Removal

- (void)remove:(NSString *)key { [_settings removeObjectForKey:key]; }


#pragma mark - Setting block getter

- (NSString*)getSettingsString
{
	return [self getSettingsStringWithAdditionalSettings:@{}];
}

- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary*)additionalSettings
{
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:_settings];
    if (additionalSettings != nil) [settings addEntriesFromDictionary:additionalSettings];
    	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:settings options:0 error:&error];

	if (!jsonData) {
		NSLog(@"%s: error: %@", __func__, error.localizedDescription);
		return @"";
	}
    
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"%@ %@ %@", JSON_MARKER, json, JSON_MARKER_END];
}

- (NSRange)readSettingsAndReturnRange:(NSString*)string
{
	NSRange r1 = [string rangeOfString:JSON_MARKER];
	NSRange r2 = [string rangeOfString:JSON_MARKER_END];
	NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
	
	if (r1.location != NSNotFound && r2.location != NSNotFound) {
		NSString *settingsString = [string substringWithRange:rSub];
		NSData *settingsData = [settingsString dataUsingEncoding:NSUTF8StringEncoding];
		NSError *error;
		
		NSDictionary *settings = [NSJSONSerialization JSONObjectWithData:settingsData options:kNilOptions error:&error];
        
		if (!error) {
			_settings = [NSMutableDictionary dictionaryWithDictionary:settings];
		
			// Return the index where settings start
			return NSMakeRange(r1.location, r1.length + rSub.length + r2.length);
		} else {
			// Something went wrong in reading the settings. Just carry on but log a message.
			NSLog(@"ERROR: Document settings could not be read. %@", error);
			_settings = [NSMutableDictionary dictionary];
			return NSMakeRange(0, 0);
		}
	}
	
	return NSMakeRange(0, 0);
}

@end
/*
 
 olen nimennyt nämä seinät
 kodikseni
 sä et pääse enää sisään
 sä et pääse enää sisään ikinä
 
 mun kasvit kasvaa
 osaan pitää mullan kosteena
 mun kasvit kasvaa ilman sua
 
 sä et pääse enää sisään
 en tarvii sua mihinkään
 sä et pääse enää sisään
 ikinä.
 
 */
