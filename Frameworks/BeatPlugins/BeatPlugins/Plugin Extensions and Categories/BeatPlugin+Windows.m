//
//  BeatPlugin+Windows.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import "BeatPlugin+Windows.h"
#import <BeatPlugins/BeatPlugins-Swift.h>

@implementation BeatPlugin (Windows)
#if TARGET_OS_OSX

/// A plugin (HTML) window will close.
- (void)windowWillClose:(NSNotification *)notification
{
    // ?
}

/// When the plugin window is set as main window, the document will become active. (If applicable.)
- (void)windowDidBecomeKey:(NSNotification *)notification
{
    if (NSApp.mainWindow != self.delegate.documentWindow && self.delegate.documentWindow != nil) {
        @try {
            [self.delegate.documentWindow makeMainWindow];
        }
        @catch (NSException* e) {
            NSLog(@"Error when setting main window: %@", e);
        }
    }
}

#endif

#pragma mark - Plugin windows

- (void)registerPluginWindow:(id)window
{
    if (self.pluginWindows == nil) {
        self.pluginWindows = NSMutableArray.new;
        [self.delegate.pluginAgent registerPlugin:(id<BeatPluginInstance>)self];
    }
    
    [self.pluginWindows addObject:window];
#if TARGET_OS_IOS
    [self.delegate registerPluginViewController:window];
#endif
}

/// Reliably closes a plugin window
- (void)closePluginWindow:(id)sender
{
    if (self.terminating) return;

#if !TARGET_OS_IOS
    // macOS
    BeatPluginHTMLWindow *window = (BeatPluginHTMLWindow*)sender;
    
    // Run callback
    JSValue *callback = window.callback;
    if (!callback.isUndefined && ![callback isNull]) {
        [self runCallback:callback withArguments:nil];
    }
    
    // Close window and remove its reference
    if (!window.stayInMemory) [self.pluginWindows removeObject:window];
    [window closeWindow];
#else
    // iOS
    BeatPluginHTMLViewController* vc = (BeatPluginHTMLViewController*)sender;
    JSValue* callback = vc.callback;
    
    // Run callback
    if (!callback.isUndefined && !callback.isNull) {
        [self runCallback:callback withArguments:nil];
    }
    
    [vc closePanel:nil];
#endif
}


#pragma mark - Window management on macOS

#if !TARGET_OS_IOS
    /// Makes the given window move along its parent document window. **Never use with standalone plugins.**
    - (void)gangWithDocumentWindow:(NSWindow*)window
    {
        if (self.delegate.documentWindow != nil) [self.delegate.documentWindow addChildWindow:window ordered:NSWindowAbove];
    }

    /// Window no longer moves aside its document window.
    - (void)detachFromDocumentWindow:(NSWindow*)window
    {
        if (self.delegate.documentWindow != nil) [self.delegate.documentWindow removeChildWindow:window];
    }

    /// Show all plugin windows.
    - (void)showAllWindows
    {
        if (self.terminating) return;
        
        for (BeatPluginHTMLWindow *window in self.pluginWindows) {
            // If the window was already set as full screen, let's not make it appear,
            // because the content size can get wrong on macOS Sonoma
            if (!window.isFullScreen) [window appear];
        }
    }

    /// All plugin windows become normal level windows, so they no longer float above the document window.
    - (void)hideAllWindows
    {
        if (self.terminating) return;
        
        for (BeatPluginHTMLWindow *window in self.pluginWindows) {
            [window hideBehindOthers];
        }
    }
#endif



@end
/*
 
 The world is burning
 I'm on a train
 escaping the wasteland of reality
   and traveling home
 
 I still remember it:
 his strong hands carrying me
 keeping me safe from every danger in world
   except him
     himself
 
 this time it was me
 my arms around him
 helping him walk the short road to a house
 glowing warmly in the dark
 
 after trying to hit his sisters with plates
   after grabbing a knife
      "this is the end of me then"
         screaming and shouting
 we drove 100 kilometers maybe less maybe more
 to a place where they help
 people just like him
   maybe like me
 
 From dead to me
 to suddenly arisen
 but I'm not sure if he's truly risen
 if he'll ever give up
   the death inside him
     the death that's been slowly taking him away
        killing him in plain sight
 
 I can't help you
 I can't even help myself
 this is the furthest my now strong arms can take you
 you got me so far in life
   I know
 but here I draw the line
 on this door
 on these steps
 
 see you on the other side
 one way
 or another
   
 
 */
