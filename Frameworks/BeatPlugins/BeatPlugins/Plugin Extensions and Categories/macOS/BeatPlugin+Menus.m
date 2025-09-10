//
//  BeatPlugin+Menus.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 18.12.2024.
//

#import "BeatPlugin+Menus.h"
#import <BeatPlugins/BeatPlugins-Swift.h>

@implementation BeatPlugin (Menus)

#pragma mark - Menu items

#if TARGET_OS_OSX
- (void)clearMenus
{
    for (NSMenuItem* topMenuItem in self.menus)
    {
        [topMenuItem.submenu removeAllItems];
        
        // Remove menus when needed
        if ([NSApp.mainMenu.itemArray containsObject:topMenuItem]) {
            [NSApp.mainMenu removeItem:topMenuItem];
        }
    }
}

/// Adds / removes menu items based on the yurrently active document
- (void)refreshMenus
{
    for (NSMenuItem* item in self.menus) {
        if (self.delegate.documentWindow.mainWindow && ![NSApp.mainMenu.itemArray containsObject:item]) [NSApp.mainMenu addItem:item];
        else if (!self.delegate.documentWindow.mainWindow && [NSApp.mainMenu.itemArray containsObject:item]) [NSApp.mainMenu removeItem:item];
    }
}

- (BeatPluginControlMenu*)menu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>* _Nullable)items
{
    BeatPluginControlMenu* menu = [BeatPluginControlMenu.alloc initWithTitle:name];
    
    for (BeatPluginControlMenuItem* item in items) {
        [menu addItem:item];
    }
    
    NSMenuItem* topMenuItem = [NSMenuItem.alloc initWithTitle:name action:nil keyEquivalent:@""];
    
    NSMenu* mainMenu = NSApp.mainMenu;
    [mainMenu insertItem:topMenuItem atIndex:mainMenu.numberOfItems];
    [mainMenu setSubmenu:menu forItem:topMenuItem];
    
    if (self.menus == nil) self.menus = NSMutableArray.new;
    [self.menus addObject:topMenuItem];
    
    return menu;
}

- (NSMenuItem*)submenu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items
{
    NSMenuItem* topItem = [NSMenuItem.alloc initWithTitle:name action:nil keyEquivalent:@""];
    
    BeatPluginControlMenu* menu = [BeatPluginControlMenu.alloc initWithTitle:name];
    for (BeatPluginControlMenuItem* item in items) [menu addItem:item];
    topItem.submenu = menu;
    
    return topItem;
}

- (NSMenuItem*)separatorMenuItem
{
    return [NSMenuItem separatorItem];
}

- (BeatPluginControlMenuItem*)menuItem:(NSString*)title shortcut:(NSArray<NSString*>*)shortcut action:(JSValue*)method
{
    return [BeatPluginControlMenuItem.alloc initWithTitle:title shortcut:shortcut method:method];
}

- (NSMenu*)getMainMenu
{
    return NSApplication.sharedApplication.mainMenu;
}

#endif

@end
