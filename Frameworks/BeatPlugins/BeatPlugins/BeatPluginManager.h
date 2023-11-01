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
	StandalonePlugin
};

@interface BeatPluginInfo : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) BeatPluginType type;
@property (nonatomic) NSString *version;
@property (nonatomic) NSString *copyright;
@property (nonatomic) NSString *imagePath;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *html;
@property (nonatomic) NSURL *localURL;
@property (nonatomic) NSURL *bundleURL;
@property (nonatomic) bool installed;
@property (nonatomic) NSString *requiredVersion;
@property (nonatomic) bool compatible;
@property (nonatomic) NSString* updateAvailable;
- (NSDictionary*)json;
- (NSString*)imageDataOrURL;
@end

@protocol BeatPluginInfoUIItem
@property (nonatomic) NSString* pluginName;
@end

@interface BeatPluginData : NSObject
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* script;
@property (nonatomic) NSArray* files;
@property (nonatomic) NSURL* url;
@end

@interface BeatPluginManager : NSObject
@property (nonatomic) NSMutableDictionary<NSString*, id> * availablePlugins;
@property (nonatomic) NSURL *pluginURL;

+ (BeatPluginManager*)sharedManager;

- (NSArray<NSString*>*)pluginNames;
- (BeatPluginData*)pluginWithName:(NSString*)name;
- (NSString*)pathForPlugin:(NSString*)pluginName;
- (NSURL*)pluginFolderURL;

- (BeatPluginInfo*)pluginInfoFor:(NSString*)plugin;

- (NSArray<NSString*>*)disabledPlugins;
- (void)disablePlugin:(NSString*)plugin;
- (void)enablePlugin:(NSString*)plugin;
- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock;
- (void)refreshAvailablePlugins;
- (void)loadPlugins;
- (void)downloadPlugin:(NSString*)pluginName withCallback:(void (^)(NSString* pluginName))callbackBlock;
- (NSArray*)availablePluginNames;

- (void)checkForUpdates;
- (bool)isCompatible:(NSString*)requiredVersion current:(NSString*)currentVersion;
- (bool)isCompatible:(NSString*)requiredVersion; /// Shorthand which automatically compares against currently installed version
@end

NS_ASSUME_NONNULL_END
