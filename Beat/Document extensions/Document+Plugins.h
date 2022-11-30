//
//  Document+Plugins.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

@class BeatPluginManager;
@interface Document (Plugins)
@property (nonatomic, weak) BeatPluginManager *pluginManager;

- (void)setupPlugins;
- (IBAction)runPlugin:(id)sender;
- (void)runPluginWithName:(NSString*)pluginName;
- (void)registerPlugin:(id)plugin;
- (void)deregisterPlugin:(id)plugin;
- (void)updatePlugins:(NSRange)range;
- (void)updatePluginsWithSelection:(NSRange)range;
- (void)updatePluginsWithSceneIndex:(NSInteger)index;
- (void)updatePluginsWithOutline:(NSArray*)outline;

- (void)notifyPluginsThatWindowBecameMain;

- (void)addWidget:(id)widget;

// For those who REALLY, REALLY know what the fuck they are doing
- (void)setPropertyValue:(NSString*)key value:(id)value;
- (id)getPropertyValue:(NSString*)key;

@end

