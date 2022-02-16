//
//  BeatPluginManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatPluginType) {
	ToolPlugin = 0,
	ImportPlugin,
	ExportPlugin
};

@interface BeatPluginInfo : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) BeatPluginType type;
@property (nonatomic) NSString *version;
@property (nonatomic) NSString *copyright;
@property (nonatomic) NSString *image;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *html;
@property (nonatomic) NSURL *localURL;
@property (nonatomic) bool installed;
@property (nonatomic) NSString *requiredVersion;
@property (nonatomic) bool compatible;
@property (nonatomic) NSString* updateAvailable;
- (NSDictionary*)json;
@end

@interface BeatPluginData : NSObject
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* script;
@property (nonatomic) NSArray* files;
@end

@interface BeatPluginManager : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (nonatomic, strong) NSMenuItem *menuItem;
@property (nonatomic, strong) NSMenuItem *exportMenuItem;
@property (nonatomic) NSMenuItem *importMenuItem;
@property (nonatomic) NSMutableDictionary<NSString*, id> * availablePlugins;

+ (BeatPluginManager*)sharedManager;
- (NSArray*)pluginNames;
- (NSString*)scriptForPlugin:(NSString*)pluginName;
- (BeatPluginData*)pluginWithName:(NSString*)name;
- (NSString*)pathForPlugin:(NSString*)pluginName;
- (void)pluginMenuItemsFor:(NSMenu*)parentMenu runningPlugins:(NSDictionary*)runningPlugins type:(BeatPluginType)type;
- (void)openPluginFolder;
- (NSURL*)pluginFolderURL;

- (NSArray*)disabledPlugins;
- (void)disablePlugin:(NSString*)plugin;
- (void)enablePlugin:(NSString*)plugin;
- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock;
- (void)refreshAvailablePlugins;
- (void)loadPlugins;
- (void)downloadPlugin:(NSString*)pluginName library:(id)library withCallback:(void (^)(NSString* pluginName))callbackBlock;
- (NSArray*)availablePluginNames;

- (void)checkForUpdates;
- (bool)isCompatible:(NSString*)requiredVersion current:(NSString*)currentVersion;
- (bool)isCompatible:(NSString*)requiredVersion; /// Shorthand which automatically compares against currently installed version
@end

NS_ASSUME_NONNULL_END
