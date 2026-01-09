//
//  BeatPlugin+Logging.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatPlugins/BeatPlugins.h>

@protocol BeatPluginLoggingExports <JSExport>

/// Logs given string in developer console
- (void)log:(NSString*)string;
/// Opens the console programmatically
- (void)openConsole;

@end

@interface BeatPlugin (Logging) <BeatPluginLoggingExports>

/// Logs given string in developer console
- (void)log:(NSString*)string;
/// Opens the console programmatically
- (void)openConsole;

/// Report a plugin error
- (void)reportError:(NSString*)title withText:(NSString*)string;

@end

