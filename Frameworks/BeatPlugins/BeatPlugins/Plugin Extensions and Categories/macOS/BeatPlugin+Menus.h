//
//  BeatPlugin+Menus.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 18.12.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

#if TARGET_OS_OSX
    #import <AppKit/AppKit.h>
#endif

@protocol BeatPluginMenusExports <JSExport>
#pragma mark Menu items (macOS only)
#if TARGET_OS_OSX
    - (NSMenuItem*)separatorMenuItem;
    - (void)refreshMenus;
    - (NSMenu*)getMainMenu;

    JSExportAs(menu, - (BeatPluginControlMenu*)menu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
    JSExportAs(menuItem, - (BeatPluginControlMenuItem*)menuItem:(NSString*)title shortcut:(NSArray<NSString*>*)shortcut action:(JSValue*)method);
    JSExportAs(submenu, - (NSMenuItem*)submenu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
#endif
@end

@interface BeatPlugin (Menus) <BeatPluginMenusExports>
#if TARGET_OS_OSX
- (void)refreshMenus;
- (void)clearMenus;
#endif
@end
