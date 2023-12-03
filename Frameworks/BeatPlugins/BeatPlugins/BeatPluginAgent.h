//
//  BeatPluginAgent.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2023.
//

#import <Foundation/Foundation.h>
#import <BeatPlugins/BeatPlugin.h>

@interface BeatPluginAgent : NSObject
- (instancetype)initWithDelegate:(id<BeatPluginDelegate>)delegate;

- (void)registerPlugin:(id<BeatPluginInstance>)plugin;
- (void)deregisterPlugin:(id<BeatPluginInstance>)plugin;

/// Runs a plugin with a name in plugin manager.
- (void)runPluginWithName:(NSString*)pluginName;

/// Loads and registers a plugin with given code. This is used for injecting plugins into memory, including the console plugin.
- (BeatPlugin*)loadPluginWithName:(NSString*)pluginName script:(NSString*)script;

/// Returns a plugin context  by name
- (BeatPlugin*)pluginContextWithName:(NSString*)pluginName;

/// Runs a script in some plugin context with given name
- (void)call:(NSString*)script context:(NSString*)pluginName;

/// Updates plugins with a change in given range
- (void)updatePlugins:(NSRange)range;

/// Selection did change
- (void)updatePluginsWithSelection:(NSRange)range;

/// Scene did change
- (void)updatePluginsWithSceneIndex:(NSInteger)index;

/// Outline did change
- (void)updatePluginsWithOutline:(NSArray*)outline changes:(OutlineChanges* _Nullable)changes;

/// Make plugins know that window became main.
/// - note: macOS only
- (void)notifyPluginsThatWindowBecameMain;

@end

