//
//  BeatPluginAgent.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2023.
//
/**
 
 An object to handle everything plugin-related in document view classes.
 
 */

#import "BeatPluginAgent.h"
#import <BeatPlugins/BeatPlugin.h>
#import <BeatPlugins/BeatPlugin+Listeners.h>
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatCore/BeatEditorDelegate.h>

@class BeatPlugin;

@interface BeatPluginAgent() <BeatPluginAgentInstance>
@property (nonatomic, weak) id<BeatPluginDelegate> delegate;
@end

@implementation BeatPluginAgent

- (instancetype)initWithDelegate:(id<BeatPluginDelegate>)delegate
{
    self = [super init];
    if (self) self.delegate = delegate;
    return self;
}

/// Runs a plugin with a name in plugin manager.
- (void)runPluginWithName:(NSString*)pluginName
{
    // See if the plugin is running and disable it if needed
    if (self.delegate.runningPlugins[pluginName]) {
        [self.delegate.runningPlugins[pluginName] forceEnd];
        [self.delegate.runningPlugins removeObjectForKey:pluginName];
        return;
    }

    // Run a new plugin
    BeatPlugin *plugin = [BeatPlugin withName:pluginName delegate:(id<BeatPluginDelegate>)self.delegate];
    
    // Null the local variable just in case. If the plugin wishes to stay in memory, it should call registerPlugin:
    plugin = nil;
}

/// Loads and registers a plugin with given code. This is used for injecting plugins into memory, including the console plugin.
- (BeatPlugin*)loadPluginWithName:(NSString*)pluginName script:(NSString*)script
{
    if (self.delegate.runningPlugins[pluginName] != nil) return self.delegate.runningPlugins[pluginName];
    
    BeatPlugin* plugin = [BeatPlugin withName:pluginName script:script delegate:(id<BeatPluginDelegate>)self.delegate];
    plugin.restorable = false;
    return plugin;
}

/// Evaluates the given string in a plugin context
- (void)call:(NSString*)script context:(NSString*)pluginName
{
    BeatPlugin* plugin = [self pluginContextWithName:pluginName];
    [plugin call:script];
}

/// Returns actual plugin context for given plugin name. Can be used to manipulate already running plugins.
- (BeatPlugin*)pluginContextWithName:(NSString*)pluginName
{
    return self.delegate.runningPlugins[pluginName];
}

- (void)runGenericPlugin:(NSString*)script
{
    
}

- (void)registerPlugin:(id<BeatPluginInstance>)plugin
{
    self.delegate.runningPlugins[plugin.pluginName] = (BeatPlugin*)plugin;
}

- (void)deregisterPlugin:(id<BeatPluginInstance>)plugin
{
    [self.delegate.runningPlugins removeObjectForKey:plugin.pluginName];
    plugin = nil;
}

- (void)updatePlugins:(NSRange)range
{
    if (!self.delegate.runningPlugins || self.delegate.documentIsLoading) return;
    for (BeatPlugin* plugin in self.delegate.runningPlugins.allValues) {
        [plugin updateText:range];
    }
}

- (void)updatePluginsWithSelection:(NSRange)range
{
    for (BeatPlugin *plugin in self.delegate.runningPlugins.allValues) {
        [plugin updateSelection:range];
    }
}

- (void)updatePluginsWithSceneIndex:(NSInteger)index
{
    for (BeatPlugin *plugin in self.delegate.runningPlugins.allValues) {
        [plugin updateSceneIndex:index];
    }
}

- (void)updatePluginsWithOutline:(NSArray*)outline changes:(OutlineChanges* _Nullable)changes
{
    for (BeatPlugin *plugin in self.delegate.runningPlugins.allValues) {
        [plugin updateOutline:changes];
    }
}

- (void)notifyPluginsThatWindowBecameMain
{
    for (BeatPlugin *plugin in self.delegate.runningPlugins.allValues) {
        [plugin documentDidBecomeMain];
    }
}


#pragma mark - Restoring plugins on load

/// Call this on load to restore plugins that were open when the document was saved. (macOS only for now)
- (void)restorePlugins
{
    bool preventRestoration = false;
#if TARGET_OS_OSX
    // Pressing shift will disable restoring plugins on macOS
    preventRestoration = (NSEvent.modifierFlags & NSEventModifierFlagShift);
#endif
    
    // Restore all plugins
    if (preventRestoration) {
        // Pressing shift stops plugins from loading and stores and empty array instead
        [self.delegate.documentSettings set:DocSettingActivePlugins as:@[]];
    } else {
        NSDictionary* plugins = [self.delegate.documentSettings get:DocSettingActivePlugins];
        for (NSString* pluginName in plugins) {
            @try {
                [self runPluginWithName:pluginName];
            } @catch (NSException *exception) {
                NSLog(@"Plugin error: %@", exception);
            }
        }
    }
}


#pragma mark - Containers

/// Removes all existing plugins from memory. 
- (void)unloadPlugins
{
    // Remove plugin containers (namely the index card view)
    for (id<BeatPluginContainer> container in self.delegate.registeredPluginContainers) {
        [container unload];
    }
    [self.delegate.registeredPluginContainers removeAllObjects];
    
    // Terminate running plugins
    for (NSString *pluginName in self.delegate.runningPlugins.allKeys) {
        BeatPlugin* plugin = self.delegate.runningPlugins[pluginName];
        [plugin end];
    }
    [self.delegate.runningPlugins removeAllObjects];
}

@end
