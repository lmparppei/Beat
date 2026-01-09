//
//  BeatPlugin+UserDefaults.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatPlugins/BeatPlugins.h>

@protocol BeatPluginUserDefaultsExports <JSExport>

#pragma mark User settings
/// Sets a user default (`key`, `value`)
JSExportAs(setUserDefault, - (void)setUserDefault:(NSString* _Nonnull)settingName setting:(id  _Nullable)value);
/// Returns a user default (`key`)
JSExportAs(getUserDefault, - (id _Nullable)getUserDefault:(NSString* _Nonnull)settingName);
/// Returns a non-prefixed user default value
JSExportAs(getRawUserDefault, - (id _Nullable)getRawUserDefault:(NSString* _Nonnull)settingName);
/// Stores a non-prefixed user default value
JSExportAs(setRawUserDefault,- (void)setRawUserDefault:(NSString* _Nonnull)settingName value:(id _Nullable)value);

@end


@interface BeatPlugin (UserDefaults) <BeatPluginUserDefaultsExports>

/// Defines plugin-specific user setting value for the given key.
- (void)setUserDefault:(NSString* _Nonnull)settingName setting:(id _Nullable)value;

/// Gets plugin-specific user setting value for the given key.
- (id _Nullable)getUserDefault:(NSString* _Nonnull)settingName;

/// Returns the non-prefixed user default (meaning any generic user default you can think of)
- (id _Nullable)getRawUserDefault:(NSString* _Nonnull)settingName;

/// Sets a non-prefixed user default
- (void)setRawUserDefault:(NSString* _Nonnull)settingName value:(id _Nullable)value;

@end

