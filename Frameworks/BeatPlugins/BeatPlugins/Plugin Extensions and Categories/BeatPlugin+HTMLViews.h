//
//  BeatPlugin+HTMLViews.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import <BeatPlugins/BeatPlugins.h>

@class BeatPluginHTMLViewController;
@class BeatPluginHTMLPanel;

@protocol BeatPluginHTMLViewExports <JSExport>

#pragma mark Displaying HTML content

/// Returns `true` when you can use promises in JS. Beat has support down to macOS 10.14 and promises were introduced to system WebKit around 12 or something.
- (bool)promisesAvailable;

#if TARGET_OS_OSX
// macOS HTML views
JSExportAs(htmlPanel, - (BeatPluginHTMLPanel*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton);
JSExportAs(htmlWindow, - (NSPanel*)htmlWindow:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback);
#else
// iOS HTML views
JSExportAs(htmlPanel, - (BeatPluginHTMLViewController*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton);
- (BeatPluginHTMLViewController*)htmlWindow:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(BOOL)cancelButton;
#endif

@end


@interface BeatPlugin (HTMLViews) <BeatPluginHTMLViewExports, WKScriptMessageHandler, WKScriptMessageHandlerWithReply>

- (NSDictionary*)htmlObjectFromValue:(JSValue*)htmlContent;

#if TARGET_OS_OSX
- (BeatPluginHTMLPanel*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton;
- (NSPanel*)htmlWindow:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback;
#else

- (BeatPluginHTMLViewController*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton;

#endif

@end
