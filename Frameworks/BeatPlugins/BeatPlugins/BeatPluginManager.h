//
//  BeatPluginManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatPluginType) {
	ToolPlugin = 0,
	ImportPlugin,
	ExportPlugin,
	StandalonePlugin,
    InternalPlugin,
    StylePlugin
};

/// Stores metadata for a plugin
@interface BeatPluginInfo : NSObject
- (instancetype)initWithURL:(NSURL*)url;

@property (nonatomic) bool installed;
@property (nonatomic) bool compatible;
@property (nonatomic) bool isFolder;

@property (nonatomic) NSString *name;
@property (nonatomic) BeatPluginType type;
@property (nonatomic) NSString *version;
@property (nonatomic) NSString *copyright;
@property (nonatomic) NSString *imagePath;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *html;
@property (nonatomic) NSURL *localURL;
@property (nonatomic) NSURL *bundleURL;
@property (nonatomic) NSURL *descriptionURL;
@property (nonatomic) NSString *requiredVersion;
@property (nonatomic) NSString* updateAvailable;
/// Returns a JSON representation of plugin information
- (NSDictionary*)json;
- (NSString*)imageDataOrURL;
@end

@protocol BeatPluginInfoUIItem
@property (nonatomic) NSString* pluginName;
@end

/// Object created before running a plugin and creating the VM. Includes URL, bundle files and the actual JS script. This is sent to a new plugin instance.
@interface BeatPluginData : NSObject
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* script;
@property (nonatomic) NSArray* files;
@property (nonatomic) NSURL* url;
@end

/// Handles providing plugins, as well as downloading, updating and installing plugins.
@interface BeatPluginManager : NSObject
/// Keys are plugin names values are plugin info instances. `[pluginName: BeatPluginInfo]`
@property (nonatomic) NSMutableDictionary<NSString*, BeatPluginInfo*>* availablePlugins;
@property (nonatomic) NSURL *pluginURL;
@property (nonatomic) NSArray<NSURL*>* managedURLs;

+ (BeatPluginManager*)sharedManager;

- (NSArray<NSString*>*)pluginNames;
- (BeatPluginData*)pluginWithName:(NSString*)name;
- (NSString*)pathForPlugin:(NSString*)pluginName;
- (NSURL*)pluginFolderURL;

/// Returns an array with the names for disabled plugins
- (NSArray<NSString*>*)disabledPlugins;
- (void)disablePlugin:(NSString*)plugin;
- (void)enablePlugin:(NSString*)plugin;

/// Returns an array of **all** available plugin names, including both local and external.
- (NSArray*)availablePluginNames;
/// Gets the plugin library JSON from GitHub repo. The JSON is stored into `_externalLibrary`.
- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock;
/// Refreshes plugins which are available on the external repo.
- (void)refreshAvailablePlugins;
/// Gets the info for user-installed plugins and the bundled ones
- (void)loadPlugins;

/// Downloads plugin from external repo. Once the download is finished, `callbackBlock` is called with the installed plugin name.
- (void)downloadPlugin:(NSString*)pluginName withCallback:(void (^)(NSString* pluginName))callbackBlock;

/// Checks available updates to installed plugins from external repo
- (void)checkForUpdates;

/// Shorthand which automatically compares against currently installed version
+ (bool)isCompatible:(NSString*)requiredVersion;
/// Check Beat compatibility with plugin
+ (bool)isCompatible:(NSString*)requiredVersion current:(NSString*)currentVersion;

/// Returns all installed plugins, including disabled ones
- (NSArray<BeatPluginInfo*>*)allPlugins;
- (NSArray<BeatPluginInfo*>*)allActivePlugins;

@end

NS_ASSUME_NONNULL_END
