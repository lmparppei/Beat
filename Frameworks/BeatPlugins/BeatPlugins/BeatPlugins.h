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

#import <BeatPlugins/BeatPlugin.h>
#import <BeatPlugins/BeatPlugin+Listeners.h>
#import <BeatPlugins/BeatPlugin+HTMLViews.h>
#import <BeatPlugins/BeatPlugin+Windows.h>
#import <BeatPlugins/BeatPlugin+Logging.h>

#import <BeatPlugins/BeatPluginTimer.h>
#import <BeatPlugins/BeatPluginManager.h>
#import <BeatPlugins/BeatConsole.h>
#import <BeatPlugins/BeatPluginAgent.h>

#if TARGET_OS_OSX
#import <BeatPlugins/BeatHTMLPrinter.h>
#import <BeatPlugins/BeatPluginUI.h>
#import <BeatPlugins/BeatWidgetView.h>
#import <BeatPlugins/BeatModalAccessoryView.h>
#import <BeatPlugins/BeatSpeak.h>
#endif
