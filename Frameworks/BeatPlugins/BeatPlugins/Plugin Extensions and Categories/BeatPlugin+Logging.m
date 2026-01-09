//
//  BeatPlugin+Logging.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatPlugin+Logging.h"

@implementation BeatPlugin (Logging)

#pragma mark - Logging

/// Opens plugin developer log
- (void)openConsole
{
    [BeatConsole.shared openConsole];
}

/// Clears plugin log
- (IBAction)clearConsole:(id)sender
{
    [BeatConsole.shared clearConsole];
}

/// Logs the given message to plugin developer log
- (void)log:(NSString*)string
{
    if (string == nil) string = @"";
    
    #if TARGET_OS_OSX
        BeatConsole *console = BeatConsole.shared;
        if (NSThread.isMainThread) [console logToConsole:string pluginName:(self.pluginName != nil) ? self.pluginName : @"General" context:self.delegate];
        else {
            // Allow logging in background thread
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [console logToConsole:string pluginName:self.pluginName context:self.delegate];
            });
        }
    #else
        // iOS doesn't have a log window, we'll just use Xcode console
        NSLog(@"%@: %@", self.pluginName, string);
    #endif
}

/// Report a plugin error
- (void)reportError:(NSString*)title withText:(NSString*)string
{
    NSString* msg = [NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string];
    [BeatConsole.shared logError:msg context:self pluginName:self.pluginName];
}

@end
