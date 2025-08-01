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

#define JSON_MARKER @"/* If you're seeing this, you can remove the following stuff - BEAT:"
#define JSON_MARKER_END @"END_BEAT */"

#define SETTING_BLOCK_OPEN @"/** settings: "
#define SETTING_BLOCK_CLOSE @"**/"

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

NSString * const DocSettingTextLengthAtSave = @"Text Length";

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


#pragma mark - Version control helpers

/// Returns an array of ESSENTIAL values. This is used by version control to store crucial information from settings and nothing else.
+ (NSArray<NSString*>*)essentialValues
{
    return @[DocSettingStylesheet, DocSettingReviews, DocSettingRevisions, DocSettingRevisionLevel];
}

/// Returns the opener and terminator
+ (NSArray<NSString*>*)blockSeparators
{
    return @[JSON_MARKER, JSON_MARKER_END];
}


#pragma mark - Default values

+ (NSDictionary*)defaultValues
{
    static NSDictionary* defaultValues;
    if (defaultValues != nil) return defaultValues;
    
    defaultValues = @{
        DocSettingStylesheet: @"Screenplay",
        DocSettingNovelLineHeightMultiplier: @(2.0),
        DocSettingHeaderAlignment: @1,
        DocSettingPrintSceneNumbers: @(true),
        DocSettingContentAlignment: @"",
        DocSettingFirstPageNumber: @1,
        DocSettingPageNumberingMode: @0,
        
        DocSettingPrintNotes: @0,
        DocSettingPrintSections: @0,
        DocSettingPrintSynopsis: @0,
        DocSettingPrintSceneNumbers: @1,
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

/// Returns a setting string with only selected keys
- (NSString*)getSettingsStringWithKeys:(NSArray<NSString*>*)keys
{
    NSMutableDictionary* settings = NSMutableDictionary.new;
    for (NSString* key in keys) {
        settings[key] = self.settings[key];
    }
    
    return [self createSettingsBlockWithDictionary:settings];
}

- (NSString*)createSettingsBlockWithDictionary:(NSDictionary*)settings
{
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:settings options:0 error:&error];
    
    if (jsonData == nil) {
        NSLog(@"%s: error: %@", __func__, error.localizedDescription);
        return @"";
    }
    
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"%@ %@ %@", JSON_MARKER, json, JSON_MARKER_END];
}

- (NSString*)getSettingsString
{
    return [self getSettingsStringWithAdditionalSettings:@{} excluding:nil];
}

- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings
{
    return [self getSettingsStringWithAdditionalSettings:additionalSettings excluding:nil];
}

- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings excluding:(NSArray<NSString*>* _Nullable)excludedKeys
{
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:_settings];
    if (additionalSettings != nil) [settings addEntriesFromDictionary:additionalSettings];
    
    // Remove excluded keys
    for (NSString* key in excludedKeys)
        [settings removeObjectForKey:key];
    
    return [self createSettingsBlockWithDictionary:settings];
}

- (NSRange)readSettingsAndReturnRange:(NSString*)string
{
    NSRange range = [self rangeForSettingsIn:string];
    
    // No range available
    if (range.location == NSNotFound || range.location < 0 || range.length < 0) return NSMakeRange(0, 0);
    
    // Find the actual JSON
    NSString* settingsBlock = [string substringWithRange:range];
    
    NSInteger jsonOpen = [settingsBlock rangeOfString:@"{"].location;
    NSInteger jsonClose = [settingsBlock rangeOfString:@"}" options:NSBackwardsSearch].location + 1;
    
    NSString* json = [settingsBlock substringWithRange:NSMakeRange(jsonOpen, jsonClose - jsonOpen)];
    
    NSError *error;
    [self readSettings:json error:&error];
    
    return (error == nil) ? range : NSMakeRange(0, 0);
}

- (void)readSettings:(NSString*)json error:(NSError**)error
{
    NSData *settingsData = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *settings = [NSJSONSerialization JSONObjectWithData:settingsData options:kNilOptions error:error];
    
    if (*error == nil) {
        _settings = [NSMutableDictionary dictionaryWithDictionary:settings];
    } else {
        // Something went wrong in reading the settings. Just carry on but log a message.
        NSLog(@"ERROR: Document settings could not be read. %@", *error);
        _settings = NSMutableDictionary.new;
    }
}

- (NSRange)rangeForModernSettingsIn:(NSString*)string
{
    NSRange openRange = [string rangeOfString:SETTING_BLOCK_OPEN];
    NSRange closeRange = [string rangeOfString:SETTING_BLOCK_CLOSE options:NSBackwardsSearch];
    
    // No setting block available
    if (openRange.location == NSNotFound || closeRange.location == NSNotFound) return NSMakeRange(NSNotFound, 0);
    
    return NSMakeRange(openRange.location, NSMaxRange(closeRange) - openRange.location);
}

- (NSRange)rangeForSettingsIn:(NSString*)string
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    if ([string containsString:JSON_MARKER]) {
        NSRange openRange = [string rangeOfString:JSON_MARKER];
        NSRange closeRange = [string rangeOfString:JSON_MARKER_END options:NSBackwardsSearch];
        
        if (openRange.location != NSNotFound && closeRange.location != NSNotFound)
            range = NSMakeRange(openRange.location, NSMaxRange(closeRange) - openRange.location);
        
        // NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
    }
    
    return range;
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
