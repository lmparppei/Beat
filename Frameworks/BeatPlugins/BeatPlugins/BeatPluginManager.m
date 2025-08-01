//
//  BeatPluginManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Provides a list of plugin names and a runnable JS script for the plugin.
 
 Also handles downloading plugins from the GitHub repository. The address is HARD-CODED.
 For now, I'm the only admin in that repository. There is a risk of it becoming an attack-vector
 for malicious purposes, but Beat is sandboxed, so even while the API allows the plugins to
 write files, the operations have to be approved by the user.
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatPluginManager.h"
#import <UnzipKit/UnzipKit.h>
#import "BeatPlugin.h"
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatCore/BeatLocalization.h>
#import <BeatCore/BeatCore-Swift.h>
#import <os/log.h>

// Hard-coded JSON file URL
#define PLUGIN_LIBRARY_URL @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Beat%20Plugins.json"

#define DOWNLOAD_URL_BASE @"raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/"
#define DOWNLOAD_URL_IMAGES @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Images/"
#define PLUGIN_FOLDER @"Plugins"
#define STYLES_FOLDER @"Styles"
#define DISABLED_KEY @"Disabled Plugins"

@implementation BeatPluginData

@end

@implementation BeatPluginInfo

- (instancetype)initWithInfo:(NSDictionary*)info
{
    self = [super init];
    if (self) {
        self.name = info[@"name"];
        self.text = info[@"text"];
        self.copyright = info[@"copyright"];
        self.version = info[@"version"];
        self.imagePath = info[@"imagePath"];
        //self.image = info[@"image"];
        self.html = info[@"html"];
    }
    
    return self;
}

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    
    if (self) {
        bool isFolder = false;
        if (![NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isFolder]) return nil;
        
        // Take note of the bundle URL if this is a folder plugin
        if (isFolder) {
            self.isFolder = true;
            self.bundleURL = url;
        }
        
        self.localURL = url;
        [self loadLocalInfo];
    }
    
    return self;
}

/// Returns plugin data, which means files and the actual script
- (BeatPluginData*)pluginInstance
{
    BeatPluginData *plugin = [[BeatPluginData alloc] init];
    plugin.name = self.name;
    
    // Uh. Let's reload the plugin array. The user might have installed new ones.
    NSURL* mainScriptURL = self.mainScriptURL;
    
    NSFileManager* fileManager = NSFileManager.defaultManager;
    NSError* error;
    
    plugin.url = (self.bundleURL != nil) ? self.bundleURL : self.localURL;
    plugin.script = [NSString stringWithContentsOfURL:mainScriptURL encoding:NSUTF8StringEncoding error:&error];

    
    if (self.isFolder) {
        // Also, read the folder contents and allow file access to the plugin
        NSArray* files = [fileManager contentsOfDirectoryAtPath:plugin.url.path error:nil];
        NSMutableArray *pluginFiles = NSMutableArray.new;
        
        for (NSString* file in files) {
            // Don't include the plugin script
            if ([file.lastPathComponent isEqualToString:mainScriptURL.lastPathComponent]) continue;
            [pluginFiles addObject:file];
        }
        
        plugin.files = [NSArray arrayWithArray:pluginFiles];
    }
        
    if (error != nil) {
        NSLog(@"Plugin instance error: %@ - %@", self.name, error);
    }
    
    // Make the script a self-running function. This allows us to avoid some namespacing issues in JS.
    plugin.script = [NSString stringWithFormat:@"(function(){ %@ })();", plugin.script];

    return plugin;
}


- (void)loadLocalInfo
{
    // Get plugin script contents
    NSError *error;
    NSString *script = [NSString stringWithContentsOfURL:self.descriptionURL encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"%@ / ERROR %@", self.localURL, error);
        return;
    }
    
    NSString* pluginName = self.localURL.lastPathComponent.stringByDeletingPathExtension;
    
    self.name = pluginName;
    self.installed = true;
    
    // Regexes for getting plugin info
    Rx* versionRx = [Rx rx:@"\nVersion:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* copyrightRx = [Rx rx:@"\nCopyright:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* descriptionRx = [Rx rx:@"\nDescription:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* typeRx = [Rx rx:@"\nType:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* imageRx = [Rx rx:@"\nImage:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* compatibilityRx = [Rx rx:@"\nCompatibility:(.*)\n" options:NSRegularExpressionCaseInsensitive];
    Rx* htmlRx = [Rx rx:@"<Description>((.|\n)*)</Description>" options:NSRegularExpressionCaseInsensitive];
    
    RxMatch *matchVersion = [script firstMatchWithDetails:versionRx];
    RxMatch *matchCopyright = [script firstMatchWithDetails:copyrightRx];
    RxMatch *matchDescription = [script firstMatchWithDetails:descriptionRx];
    RxMatch *matchType = [script firstMatchWithDetails:typeRx];
    RxMatch *matchImage = [script firstMatchWithDetails:imageRx];
    RxMatch *matchHTML = [script firstMatchWithDetails:htmlRx];
    RxMatch *matchCompatibility = [script firstMatchWithDetails:compatibilityRx];
        
    if (matchVersion) self.version = [[(RxMatchGroup*)matchVersion.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (matchCopyright) self.copyright = [[(RxMatchGroup*)matchCopyright.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (matchDescription) self.text = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (matchHTML) self.html = [[(RxMatchGroup*)matchHTML.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    
    // Check compatibility
    self.compatible = YES;
    if (matchCompatibility) {
        self.requiredVersion = [[(RxMatchGroup*)matchCompatibility.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        self.requiredVersion = [self.requiredVersion stringByReplacingOccurrencesOfString:@"+" withString:@""];
        
        if (self.requiredVersion.length && ![BeatPluginManager isCompatible:self.requiredVersion]) self.compatible = NO;
    }
    
    if (matchImage) {
        NSString *image = [[(RxMatchGroup*)matchImage.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        self.imagePath = image;
    }
    
    if (matchType) {
        NSString *typeString = [[(RxMatchGroup*)matchType.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
        BeatPluginType type = ToolPlugin;
                
        if ([typeString isEqualToString:@"export"]) type = ExportPlugin;
        else if ([typeString isEqualToString:@"import"]) type = ImportPlugin;
        else if ([typeString isEqualToString:@"standalone"]) type = StandalonePlugin;
        else if ([typeString isEqualToString:@"internal"]) type = InternalPlugin;
        else if ([typeString isEqualToString:@"style"]) type = StylePlugin;
        
        self.type = type;
    } else {
        if ([self.localURL.pathExtension isEqualToString:@"beatCSS"]) self.type = StylePlugin;
    }
}

- (NSURL*)mainScriptURL
{
    if (self.bundleURL == nil) return self.localURL;
    return [self findBundleFileThatMatches:self.mainPluginFileNames];
}

- (NSURL*)descriptionURL
{
    if (self.bundleURL == nil) return self.localURL;
    return [self findBundleFileThatMatches:[self.mainPluginFileNames arrayByAddingObject:@"_description"]];
}

- (NSArray<NSString*>*)mainPluginFileNames
{
    NSString* pluginName = self.localURL.lastPathComponent;
    return @[pluginName, @"plugin.js", [NSString stringWithFormat:@"%@.beatCSS", pluginName], [NSString stringWithFormat:@"%@.js", pluginName]];
}

- (NSURL*)findBundleFileThatMatches:(NSArray<NSString*>*)possibleNames
{
    for (NSString* filename in possibleNames) {
        NSString* path = [self.bundleURL.path stringByAppendingPathComponent:filename];
        if ([NSFileManager.defaultManager fileExistsAtPath:path])
            return [NSURL fileURLWithPath:path];
    }
    return nil;

}

- (NSString*)typeAsString
{
    switch (self.type) {
        case ToolPlugin:
            return @"tool";
        case ImportPlugin:
            return @"import";
        case ExportPlugin:
            return @"export";
        case StandalonePlugin:
            return @"standalone";
        case InternalPlugin:
            return @"internal";
        case StylePlugin:
            return @"style";
    }
    return @"";
}

- (NSDictionary*)json {
	return @{
		@"name": (self.name) ? self.name : @"",
		@"text": (self.text) ? self.text : @"",
		@"copyright": (self.copyright) ? self.copyright : @"",
		@"version": (self.version) ? self.version : @"",
		@"localURL": (self.localURL) ? self.localURL.path : @"",
		@"updateAvailable": (self.updateAvailable) ? self.updateAvailable : @"",
		@"imagePath": (self.imagePath) ? self.imagePath : @"",
		@"image": [self imageDataOrURL], // sends either a base64 data or a URL
		@"html": (self.html) ? self.html : @"",
        @"type": self.typeAsString,

		// If a required version is set, we have already checked compatibility.
		// Otherwise, let's always assume the plugin is comppatible.
		@"compatible": (self.requiredVersion) ? @(self.compatible) : @(YES)
	};
}

- (NSString*)imageDataOrURL
{
	NSString *imagePath;
	
	// No image
	if (self.imagePath.length == 0) return @"";
	
	// Return remote url
	else if ([self.imagePath rangeOfString:@"http"].location != NSNotFound) {
		return (self.imagePath) ? self.imagePath : @"";
	}
	
	// Return base64 representation
	else if (_localURL) {
		imagePath = [_bundleURL.path stringByAppendingPathComponent:self.imagePath];
		
		NSError *error;
		NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:imagePath] options:0 error:&error];
		
		if (!error) {
			NSString *imgData = [NSString stringWithFormat:@"data:image/png;base64, %@", [data base64EncodedStringWithOptions:0]];
			return imgData;
		}
	}
	
	return @"";
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Plugin: %@ - %@", self.name, self.typeAsString];
}

@end


@interface BeatPluginManager ()

@property (nonatomic) NSDictionary<NSString*, BeatPluginInfo*>* plugins;
@property (nonatomic) NSMutableSet *incompleteDownloads;
@property (nonatomic) NSDictionary *externalLibrary;
@end

@implementation BeatPluginManager

// NB: Plugin manager is a singleton, and first loaded in MainMenu.xib

static BeatPluginManager *sharedManager;

+ (BeatPluginManager*)sharedManager
{
	if (!sharedManager) {
		sharedManager = [[BeatPluginManager alloc] init];
	}
	return sharedManager;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		NSLog(@"Initializing plugin manager...");
		initialized = YES;
		sharedManager = BeatPluginManager.new;
	}
}

- (BeatPluginManager*)init
{
	self = [super init];
	
	if (sharedManager) return sharedManager;
		
	if (self) {
        _managedURLs = @[[BeatPaths appDataPath:PLUGIN_FOLDER], [BeatPaths appDataPath:STYLES_FOLDER]];
		[self loadPlugins];
	}
	
	return self;
}

- (NSURL *)pluginURL
{
    return [BeatPaths appDataPath:PLUGIN_FOLDER];
}


#pragma mark - Run plugins

- (void)runPlugin:(id)plugin
{
	// Faux placeholder method
}

- (IBAction)runStandalonePlugin:(id)sender
{
	// This runs a plugin which is NOT tied to the document
#if !TARGET_OS_IOS
	id<BeatPluginInfoUIItem> item = sender;
	NSString *pluginName = item.pluginName;
	
    BeatPluginInfo *pluginInfo = _plugins[pluginName];
    BeatPluginData *pluginData = [pluginInfo pluginInstance];
    
    BeatPlugin *plugin = BeatPlugin.new;
    [plugin loadPlugin:pluginData];
	
	// If the plugin was an export or import plugin, it might have not run any code, but registered a callback.
    if (pluginInfo.type == ExportPlugin && plugin.exportCallback != nil) {
		[self runExportPlugin:plugin];
	} else if (pluginInfo.type == ImportPlugin && plugin.importCallback != nil) {
		[self runImportPlugin:plugin];
	}
	
    plugin = nil;
#endif
}

#pragma mark Export / Import plugins (macOS)

#if !TARGET_OS_IOS
- (void)runExportPlugin:(BeatPlugin*)parser
{
	NSSavePanel *panel = NSSavePanel.new;
	panel.allowedFileTypes = parser.exportedExtensions;
	
	[panel beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[parser.exportCallback callWithArguments:@[panel.URL.path]];
		}
	}];
}

- (void)runImportPlugin:(BeatPlugin*)parser
{
	NSOpenPanel *panel = NSOpenPanel.new;
	panel.allowedFileTypes = parser.importedExtensions;
	
	[panel beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[parser.importCallback callWithArguments:@[panel.URL.path]];
		}
	}];
}
#endif


#pragma mark - Plugin folder access

- (NSURL*)pluginFolderURL
{
	return [BeatPaths appDataPath:PLUGIN_FOLDER];
}


#pragma mark - Check for plugin updates

- (void)checkForUpdates
{
	bool autoUpdate = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUpdatePluginsAutomatically];
	
	[self refreshAvailablePlugins];
	[self getPluginLibraryWithCallback:^{
		NSMutableArray *availableUpdates = NSMutableArray.new;
		
		for (NSString *name in self.availablePlugins.allKeys) {
			BeatPluginInfo *plugin = self.availablePlugins[name];
			
			// Don't check updates for disabled plugins
			// if ([disabled containsObject:name]) continue;
			
			// If the plugin has a update available, add it to the list
			if (plugin.updateAvailable) [availableUpdates addObject:name];
		}
		
		
		if (availableUpdates.count == 0) return;
		
		// Update plugins automatically or show a notification
		if (autoUpdate) {
			[self updatePlugins:availableUpdates];
		} else {
            #if !TARGET_OS_IOS
            // Show notification if there are updates available (on macOS)
            NSString *text = [NSString stringWithFormat:@"%@", [availableUpdates componentsJoinedByString:@", "]];
            id<BeatNotificationDelegate> notifications = (id<BeatNotificationDelegate>)NSApp.delegate;
            [notifications showNotification:@"Update Available" body:text identifier:@"PluginUpdates" oneTime:YES interval:5.0];
            #endif
		}
	}];
}

- (void)updatePlugins:(NSArray*)availableUpdates
{
	for (NSString* name in availableUpdates) {
		[self downloadPlugin:name withCallback:^(NSString * _Nonnull pluginName) {
            #if !TARGET_OS_IOS
            id<BeatNotificationDelegate> notifications = (id<BeatNotificationDelegate>)NSApp.delegate;
			[notifications showNotification:@"Plugin Updated" body:pluginName identifier:@"PluginUpdates" oneTime:YES interval:3.0];
            #endif
        }];
	}
}


#pragma mark - Disabling and enabling plugins

- (NSArray<NSString*>*)disabledPlugins
{
	return [NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY];
}

- (void)disablePlugin:(NSString*)plugin
{
	NSMutableArray *disabledPlugins = [NSMutableArray arrayWithArray:[NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY]];
	[disabledPlugins addObject:plugin];
	[NSUserDefaults.standardUserDefaults setValue:disabledPlugins forKey:DISABLED_KEY];
}

- (void)enablePlugin:(NSString *)plugin
{
	NSMutableArray *disabledPlugins = [NSMutableArray arrayWithArray:[NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY]];
	if ([disabledPlugins containsObject:plugin]) [disabledPlugins removeObject:plugin];
	[NSUserDefaults.standardUserDefaults setValue:disabledPlugins forKey:DISABLED_KEY];
}


#pragma mark - Plugin library content

- (void)refreshAvailablePlugins
{
	self.availablePlugins = NSMutableDictionary.new;
	
	for (NSString *pluginName in self.plugins.allKeys) {
        BeatPluginInfo* plugin = _plugins[pluginName];
        if (plugin.type == InternalPlugin) continue;
        
        _availablePlugins[pluginName] = plugin;
	}
}

- (void)refreshAvailablePluginsWithExternalLibrary
{
	for (NSString *pluginName in self.externalLibrary.allKeys) {
		BeatPluginInfo *remotePlugin = self.externalLibrary[pluginName];
		
		if (_availablePlugins[pluginName]) {
			// The plugin is already available, check for updates
			BeatPluginInfo *existingPlugin = _availablePlugins[pluginName];
						
            if ([remotePlugin.version isNewerVersionThan:existingPlugin.version]
                && ![remotePlugin.version isEqualToString:existingPlugin.version]) {
				// There's an update available, so show the remote info instead
				existingPlugin.updateAvailable = remotePlugin.version;
				existingPlugin.text = (remotePlugin.text) ? remotePlugin.text : @"";
				existingPlugin.html = (remotePlugin.html) ? remotePlugin.html : @"";
				existingPlugin.imagePath = (remotePlugin.imagePath) ? remotePlugin.imagePath : @"";
			}
			[_availablePlugins setValue:existingPlugin forKey:pluginName];
		} else {
			[_availablePlugins setValue:remotePlugin forKey:pluginName];
		}
	}
}

- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock
{
	NSString *urlAsString = PLUGIN_LIBRARY_URL;

	// Download external JSON data
	NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
	[[session dataTaskWithURL:[NSURL URLWithString:urlAsString]
			completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
				
		// No data available (we are offline)
		if (error || data == nil) return;
		
		// Read JSON data and init the local dictionary
		NSDictionary *pluginData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		NSMutableDictionary *plugins = NSMutableDictionary.new;
		
		// Iterate through remote plugin data
		for (NSString *pluginName in pluginData.allKeys) {
			NSDictionary *data = pluginData[pluginName];
			NSString *name = pluginName.stringByDeletingPathExtension;
			
			// Never add stuff with no name
			if (name.length == 0) continue;
			
			// Plugin image URL
			NSString *imageURL = @"";
			if ([(NSString*)data[@"image"] length]) imageURL = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_IMAGES, data[@"image"]];
			
			BeatPluginInfo *info = BeatPluginInfo.alloc.init;
			[info setValuesForKeysWithDictionary:@{
				@"name": name,
                @"type": (data[@"type"]) ? data[@"type"] : @"",
				@"version": (data[@"version"]) ? data[@"version"] : @"",
				@"copyright": (data[@"copyright"]) ? data[@"copyright"] : @"",
				@"text": (data[@"description"]) ? data[@"description"] : @"",
				@"imagePath": imageURL,
				@"html": (data[@"html"]) ? data[@"html"] : @"",
				@"installed": @(NO),
			}];
			
			[plugins setValue:info forKey:name];
		}
		
		// Save the downloaded data and append it to local plugin information
		self.externalLibrary = plugins;
		[self refreshAvailablePluginsWithExternalLibrary];
		
		// Run callback
		dispatch_async(dispatch_get_main_queue(), ^(void){
			callbackBlock();
		});
	}] resume];
}

/// Loads the local plugins.
/// A plugin can be either a single file (`.js` or `.beatPlugin`) *or* a folder which contains one of these:
/// `FolderName.js`, `FolderName.beatPlugin`, `plugin.js`, `plugin.beatPlugin`
- (void)loadPlugins
{
	NSMutableArray<BeatPluginInfo*>* plugins = NSMutableArray.new;
    
	// Plugins from inside the bundle
	NSArray *bundledPlugins = [NSBundle.mainBundle URLsForResourcesWithExtension:@"beatPlugin" subdirectory:nil];
	for (NSURL *url in bundledPlugins) {
        BeatPluginInfo* plugin = [BeatPluginInfo.alloc initWithURL:url];
        [plugins addObject:plugin];
	}
		
    // Append installed plugins from all managed URLs
    for (NSURL* url in _managedURLs) {
        NSArray* installedPlugins = [self pluginsInPath:url];
        [plugins addObjectsFromArray:installedPlugins];
    }
	
	NSMutableDictionary *pluginsWithNames = NSMutableDictionary.new;
    for (BeatPluginInfo* plugin in plugins) {
        if (plugin.name == nil) continue;
        
        pluginsWithNames[plugin.name] = plugin;
	}
    
	_plugins = pluginsWithNames;
}

- (NSArray<BeatPluginInfo*>*)pluginsInPath:(NSURL*)url
{
    NSMutableArray<BeatPluginInfo*>* plugins = NSMutableArray.new;
    
    // Get user-installed plugins
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSArray<NSURL*>* urls = [fileManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:nil];
    
    for (NSURL* url in urls) {
        BOOL folder;
        
        if ([fileManager fileExistsAtPath:url.path isDirectory:&folder]) {
            if (!folder) {
                // Skip non-folder files if they are not standalone items
                NSString* extension = url.pathExtension.lowercaseString;
                if (extension.length == 0 || (![extension isEqualToString:@"beatplugin"] && [extension isEqualToString:@"beatcss"] && [extension isEqualToString:@"js"])) continue;
            }
            
            BeatPluginInfo* plugin = [BeatPluginInfo.alloc initWithURL:url];
            if (plugin != nil) [plugins addObject:plugin];
        }
    }
    
    return plugins;
}

/// Returns an array of plugin names
- (NSArray<NSString*>*)pluginNames
{
	return [self.plugins.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<BeatPluginInfo*>*)allPluginsWithDisabledOnes:(BOOL)includeDisabled
{
    NSMutableArray<BeatPluginInfo*>* plugins = [NSMutableArray.alloc initWithCapacity:self.plugins.count];
    NSArray* keys = [self.plugins.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString* key in keys) {
        if (includeDisabled == false && [self.disabledPlugins containsObject:key]) continue;
        [plugins addObject:self.plugins[key]];
    }
    return plugins;
}

- (NSArray<BeatPluginInfo*>*)allPlugins
{
    return [self allPluginsWithDisabledOnes:true];
}

- (NSArray<BeatPluginInfo*>*)allActivePlugins
{
    return [self allPluginsWithDisabledOnes:false];
}

/// Returns plugin data, which means files and the actual script
- (BeatPluginData*)pluginWithName:(NSString*)name
{
	// Uh. Let's reload the plugin array. The user might have installed new ones.
	[self loadPlugins];

    BeatPluginInfo* plugin = _plugins[name];
    return (plugin != nil) ? [plugin pluginInstance] : nil;
}

- (NSString*)pathForPlugin:(NSString*)pluginName
{
    BeatPluginInfo* plugin = _plugins[pluginName];
    return plugin.localURL.path;
}
 
 
#pragma mark - Plugin version checking

+ (bool)isCompatible:(NSString*)requiredVersion current:(NSString*)currentVersion
{
    return [currentVersion isNewerVersionThan:requiredVersion];
}

+ (bool)isCompatible:(NSString*)requiredVersion
{
	NSString * currentVersion = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
	currentVersion = currentVersion.shortenedVersionNumberString;
    return [BeatPluginManager isCompatible:requiredVersion current:currentVersion];
}
 
- (NSArray*)availablePluginNames
{
	return [self.availablePlugins.allKeys sortedArrayUsingSelector:@selector(compare:)];
}


#pragma mark - File Access

- (void)deletePlugin:(NSString*)name
{
    BeatPluginInfo *plugin = _plugins[name];
    NSURL *url = plugin.localURL;
	
	NSError *error;
	[NSFileManager.defaultManager removeItemAtURL:url error:&error];
	if (error) os_log(OS_LOG_DEFAULT, "Error deleting plugin: %@", name);
}

- (void)downloadPlugin:(NSString*)pluginName withCallback:(void (^)(NSString* pluginName))callbackBlock
{
	if (!_incompleteDownloads) _incompleteDownloads = NSMutableSet.set;
	[_incompleteDownloads addObject:pluginName];
	
	__block NSString *pluginFileName = [NSString stringWithFormat:@"%@.beatPlugin.zip", pluginName];
	
	NSString *downloadPath = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_BASE, pluginFileName];
	downloadPath = [downloadPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
	downloadPath = [NSString stringWithFormat:@"https://%@", downloadPath];
	
	NSURL *url = [NSURL URLWithString:downloadPath];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	
	[[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSError *writeError;
		NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:pluginFileName];
		
		[data writeToURL:[NSURL fileURLWithPath:tempDir] options:0 error:&writeError];
		
		if (writeError) {
			os_log(OS_LOG_DEFAULT, "Error writing temporary zip file: %@", writeError);
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void){
				NSLog(@"Installing plugin...");
				@try {
					[self installPlugin:tempDir];
                    
                    BeatPluginInfo* plugin = self.plugins[pluginName];
                    if (plugin == nil) {
                        NSLog(@"ERROR: Plugin was not found after installation");
                        return;
                    }
                    
                    NSString* path = plugin.localURL.path;
                    
                    if (path != nil) {
                        BeatPluginInfo* info = [BeatPluginInfo.alloc initWithURL:[NSURL fileURLWithPath:path]];
                        [self.availablePlugins setValue:info forKey:pluginName];
                        callbackBlock(pluginName);
                    } else {
                        NSLog(@"ERROR: Install failed");
                    }
				}
				@catch (NSException* e) {
					os_log(OS_LOG_DEFAULT, "Error installing plugin %@", pluginName);
				}
				@finally {
					[self.incompleteDownloads removeObject:pluginName];
				}
			});
		}
	}] resume];
}

- (void)installPlugin:(NSString*)path
{
	NSURL *url = [NSURL fileURLWithPath:path];
	    
	NSError *error;
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:&error];
	if (error || !container) return;
    
    // We need to get the plugin info here to know where to put the plugin.
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[path.lastPathComponent.stringByDeletingPathExtension stringByReplacingOccurrencesOfString:@" " withString:@"_"]];
    [container extractFilesTo:tempDir overwrite:YES error:&error];
    
    if (error) {
        NSLog(@"Error extracting plugin to temp dir: %@", tempDir);
        return;
    }
    
    // Extract the plugin to a temporary directory and get the info.
    NSString* fullTempDir = [tempDir stringByAppendingPathComponent:path.lastPathComponent.stringByDeletingPathExtension];
    BeatPluginInfo* info = [BeatPluginInfo.alloc initWithURL:[NSURL fileURLWithPath:fullTempDir]];
    
    NSString* destination = PLUGIN_FOLDER;
    if (info.type == StylePlugin) destination = STYLES_FOLDER;
    
	// Get & create final plugin path and re-extract to be on the safe side.
    NSURL *pluginURL = [BeatPaths appDataPath:destination];
	[container extractFilesTo:pluginURL.path overwrite:YES error:&error];
	
	// Reload installed plugins
	[self loadPlugins];
}


@end
/*
 
 when it is truly time
 and if you have been chosen
 it will do it by
 itself and it will keep on doing it
 until you die or it dies in you.
 
 */
