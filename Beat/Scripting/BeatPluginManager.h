//
//  BeatPluginManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
	GenericPlugin = 0,
	ImportPlugin,
	ToolPlugin,
	StandalonePlugin
} BeatPluginType;

@interface BeatPluginManager : NSObject
+ (BeatPluginManager*)sharedManager;
- (NSArray*)pluginNames;
- (NSString*)scriptForPlugin:(NSString*)pluginName;
@end

NS_ASSUME_NONNULL_END
