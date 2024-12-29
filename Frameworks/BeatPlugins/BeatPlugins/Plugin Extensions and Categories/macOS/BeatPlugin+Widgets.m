//
//  BeatPlugin+Widgets.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 18.12.2024.
//

#import "BeatPlugin+Widgets.h"

#if TARGET_OS_OSX
#import "BeatPluginUIView.h"
#import "BeatPluginUIButton.h"
#import "BeatPluginUIDropdown.h"
#import "BeatPluginUIView.h"
#import "BeatPluginUICheckbox.h"
#import "BeatPluginUILabel.h"
#endif

@implementation BeatPlugin (Widgets)

#pragma mark - Widget interface and Plugin UI API

#if !TARGET_OS_IOS

- (BeatPluginUIView*)widget:(CGFloat)height
{
    // Allow only one widget view
    if (self.widgetView != nil) return self.widgetView;
    
    self.resident = YES;
    [self.delegate.pluginAgent registerPlugin:self];
    
    BeatPluginUIView *view = [BeatPluginUIView.alloc initWithHeight:height];
    self.widgetView = view;
    [self.delegate addWidget:self.widgetView];
    
    return view;
}

- (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame
{
    return [BeatPluginUIButton buttonWithTitle:name action:action frame:frame];
}

- (BeatPluginUIDropdown*)dropdown:(nonnull NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame
{
    return [BeatPluginUIDropdown withItems:items action:action frame:frame];
}

- (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame
{
    return [BeatPluginUICheckbox withTitle:title action:action frame:frame];
}

- (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName
{
    return [BeatPluginUILabel withText:title frame:frame color:color size:size font:fontName];
}

#endif

@end
