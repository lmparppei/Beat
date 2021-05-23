//
//  BeatPluginManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
	GenericPlugin = 0,
	ImportPlugin,
	ToolPlugin,
	StandalonePlugin
} BeatPluginType;

@interface BeatPlugin : NSObject
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* script;
@property (nonatomic) NSArray* files;
@end

@interface BeatPluginManager : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
+ (BeatPluginManager*)sharedManager;
- (NSArray*)pluginNames;
- (NSString*)scriptForPlugin:(NSString*)pluginName;
- (BeatPlugin*)pluginWithName:(NSString*)name;
- (NSString*)pathForPlugin:(NSString*)pluginName;
- (void)pluginMenuItemsFor:(NSMenu*)parentMenu runningPlugins:(NSDictionary*)runningPlugins;
- (void)openPluginFolder;

- (NSArray*)disabledPlugins;
- (void)disablePlugin:(NSString*)plugin;
- (void)enablePlugin:(NSString*)plugin;
- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock;
- (void)updateAvailablePlugins;
- (void)downloadPlugin:(NSString*)pluginName sender:(id)sender;
@end

NS_ASSUME_NONNULL_END
