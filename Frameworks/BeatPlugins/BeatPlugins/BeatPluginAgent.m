//
//  BeatPluginAgent.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2023.
//

#import "BeatPluginAgent.h"
#import <BeatCore/BeatEditorDelegate.h>

@interface BeatPluginAgent()
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

- (void)call:(NSString*)script context:(NSString*)pluginName
{
    BeatPlugin* plugin = [self pluginContextWithName:pluginName];
    [plugin call:script];
}

- (BeatPlugin*)pluginContextWithName:(NSString*)pluginName
{
    return self.delegate.runningPlugins[pluginName];
}

- (void)runGenericPlugin:(NSString*)script
{
    
}

- (void)registerPlugin:(id<BeatPluginInstance>)plugin
{
    self.delegate.runningPlugins[plugin.pluginName] = plugin;
}

- (void)deregisterPlugin:(id<BeatPluginInstance>)plugin
{
    [self.delegate.runningPlugins removeObjectForKey:plugin.pluginName];
    plugin = nil;
}

- (void)updatePlugins:(NSRange)range
{
    if (!self.delegate.runningPlugins || self.delegate.documentIsLoading) return;
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (BeatPlugin* plugin in self.delegate.runningPlugins.allValues) {
            [plugin update:range];
        }
    });
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


@end
