//
//  BeatPlugins.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 24.7.2023.
//

#import <Foundation/Foundation.h>

//! Project version number for BeatPlugins.
FOUNDATION_EXPORT double BeatPluginsVersionNumber;

//! Project version string for BeatPlugins.
FOUNDATION_EXPORT const unsigned char BeatPluginsVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <BeatPlugins/PublicHeader.h>

#import "BeatPlugin.h"
#import "BeatPluginManager.h"
#import "BeatConsole.h"

#if !TARGET_OS_IOS
#import "BeatHTMLPrinter.h"
#import "BeatPluginUI.h"
#import "BeatWidgetView.h"
#endif
