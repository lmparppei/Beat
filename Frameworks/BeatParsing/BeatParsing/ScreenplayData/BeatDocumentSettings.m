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

@interface BeatDocumentSettings ()
@end

@implementation BeatDocumentSettings

NSString * const DocSettingRevisions = @"Revision";
NSString * const DocSettingHiddenRevisions = @"Hidden Revisions";
NSString * const DocSettingRevisionColor = @"Revision Color";
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

NSString * const DocSettingWindowWidth = @"Window Width";
NSString * const DocSettingWindowHeight = @"Window Height";

NSString * const DocSettingActivePlugins = @"Active Plugins";

NSString * const DocSettingPageSize = @"Page Size";

NSString * const DocSettingCharacterGenders = @"CharacterGenders";

NSString * const DocSettingPrintSynopsis = @"Print Synopsis";
NSString * const DocSettingPrintSections = @"Print Sections";
NSString * const DocSettingPrintNotes    = @"Print Notes";

NSString * const DocSettingStylesheet    = @"Stylesheet";

NSString * const DocSettingCharacterData = @"CharacterData";


-(id)init
{
	self = [super init];
	if (self) {
		_settings = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)setBool:(NSString*)key as:(bool)value
{
	[_settings setValue:[NSNumber numberWithBool:value] forKey:key];
}
- (void)setInt:(NSString*)key as:(NSInteger)value
{
	[_settings setValue:@(value) forKey:key];
}
- (void)setFloat:(NSString*)key as:(NSInteger)value
{
	[_settings setValue:[NSNumber numberWithFloat:value] forKey:key];
}
- (void)setString:(NSString*)key as:(NSString*)value
{
	[_settings setValue:value forKey:key];
}
- (void)set:(NSString*)key as:(id)value
{
	[_settings setValue:value forKey:key];
}

- (bool)has:(NSString*)key {
	if ([_settings objectForKey:key]) return YES;
	else return NO;
}

- (NSInteger)getInt:(NSString *)key
{
	return [(NSNumber*)[_settings valueForKey:key] integerValue];
}
- (NSInteger)getFloat:(NSString *)key {
	return [(NSNumber*)[_settings valueForKey:key] floatValue];
}
- (bool)getBool:(NSString *)key
{
	return [(NSNumber*)[_settings valueForKey:key] boolValue];
}
- (NSString*)getString:(NSString *) key
{
	NSString *value = (NSString*)_settings[key];
	if (![value isKindOfClass:NSString.class]) value = @"";
	return value;
}
- (id)get:(NSString*)key
{
	return _settings[key];
}
- (void)remove:(NSString *)key
{
	[_settings removeObjectForKey:key];
}


- (NSString*)getSettingsString {
	return [self getSettingsStringWithAdditionalSettings:@{}];
}
- (NSString*)getSettingsStringWithAdditionalSettings:(NSDictionary*)additionalSettings
{
	NSDictionary *settings = _settings.copy;
	if (additionalSettings != nil) {
		NSMutableDictionary *merged = settings.mutableCopy;
		[merged addEntriesFromDictionary:additionalSettings];
		settings = merged;
	}
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:settings options:0 error:&error]; // Do NOT pretty print this to make the block more compact

	if (! jsonData) {
		NSLog(@"%s: error: %@", __func__, error.localizedDescription);
		return @"";
	} else {
		NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		return [NSString stringWithFormat:@"%@ %@ %@", JSON_MARKER, json, JSON_MARKER_END];
	}
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
