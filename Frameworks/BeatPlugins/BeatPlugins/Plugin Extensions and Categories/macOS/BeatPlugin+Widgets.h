//
//  BeatPlugin+Widgets.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 18.12.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class BeatPluginUIView;
@class BeatPluginUIDropdown;
@class BeatPluginUICheckbox;
@class BeatPluginUILabel;

@protocol BeatPluginWidgetExports <JSExport>
#pragma mark Widgets (macOS only)
#if TARGET_OS_OSX
    /// Add widget into sidebar
    - (BeatPluginUIView*)widget:(CGFloat)height;
    JSExportAs(button, - (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame);
    JSExportAs(dropdown, - (BeatPluginUIDropdown*)dropdown:(NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame);
    JSExportAs(checkbox, - (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame);
    JSExportAs(label, - (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName);
#endif
@end


@interface BeatPlugin (Widgets) <BeatPluginWidgetExports>
@end

