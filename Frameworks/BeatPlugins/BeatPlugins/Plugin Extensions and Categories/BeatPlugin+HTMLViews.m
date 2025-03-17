//
//  BeatPlugin+HTMLViews.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import "BeatPlugin+HTMLViews.h"
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatPlugins/BeatPlugin+Windows.h>

@implementation BeatPlugin (HTMLViews)

#pragma mark - HTML Window

#if TARGET_OS_OSX

/**
 @param htmlContent The actual content in the window. It's wrapped in a HTML template, so no headers are needed. If you want to provide additional headers, this value can either be an array ([content, headers]) or an object ({ html: "...", headers: "<script></script>" })
 See `htmlObjectFromValue:`.
 */
- (BeatPluginHTMLWindow*)htmlWindow:(JSValue*)htmlContent width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback
{
    // This is a floating window, so the plugin has to be resident
    self.resident = YES;
    
    NSDictionary* html = [self htmlObjectFromValue:htmlContent];
    
    NSString* content = html[@"content"];
    NSString* headers = html[@"headers"];
    
    if (width <= 0) width = 500;
    if (width > 1000) width = 1000;
    if (height <= 0) height = 300;
    if (height > 800) height = 800;
    
    BeatPluginHTMLWindow *window = [BeatPluginHTMLWindow.alloc initWithHTML:content width:width height:height headers:headers host:self];
    [self registerPluginWindow:window];
    
    [window makeKeyAndOrderFront:nil];
    window.delegate = self;
    window.callback = callback;
    
    // If no callback is provided, windows will stay in memory by default
    if (callback == nil || [callback isNull] || [callback isUndefined]) window.stayInMemory = true;
    
    return window;
}

#else

/// Returns a HTML view controller for iOS. Width and height are disregarded.
- (BeatPluginHTMLViewController*)htmlWindow:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(BOOL)cancelButton
{
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLViewController* htmlVC = [BeatPluginHTMLViewController.alloc initWithHtml:(content) ? content : @"" headers:(headers) ? headers : @""  width:width height:height host:self cancelButton:cancelButton callback:callback];
    [self registerPluginWindow:htmlVC];
        
    UIViewController* documentVC = (UIViewController*)self.delegate;
    [documentVC presentViewController:htmlVC animated:true completion:nil];
     
    return htmlVC;
}

#endif


#pragma mark - HTML panel
/**
 
 This is a complete mess. Please rewrite sometime soon.
 TODO: Rewrite HTML panel logic and move most of it to another class / category
 
 */

#if TARGET_OS_OSX
- (BeatPluginHTMLPanel*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
    if (self.delegate.documentWindow.attachedSheet) return nil;
    
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLPanel* panel = [BeatPluginHTMLPanel.alloc initWithHtml:content headers:(headers) ? headers : @"" width:width height:height host:self cancelButton:cancelButton callback:callback];
    self.htmlPanel = panel;
    
    [self makeResident];
    
    [self.delegate.documentWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
        self.htmlPanel = nil;
    }];
    
    return panel;
}
#else
- (BeatPluginHTMLViewController*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLViewController* htmlVC = [BeatPluginHTMLViewController.alloc initWithHtml:content headers:headers width:width height:height host:self cancelButton:cancelButton callback:callback];
    
    UIBarButtonItem* button = [UIBarButtonItem.alloc initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(receiveDataFromHTMLPanel:)];
    htmlVC.navigationItem.rightBarButtonItems = @[button];
    
    UINavigationController* nc = [UINavigationController.alloc initWithRootViewController:htmlVC];

    UIViewController* documentVC = (UIViewController*)self.delegate;
    [documentVC presentViewController:nc animated:true completion:nil];
    
    self.htmlPanel = htmlVC;
    return htmlVC;
}
#endif

- (void)receiveDataFromHTMLPanel:(NSString*)json
{
    if (![json isKindOfClass:NSString.class]) json = @"{}";
    
    // This method closes the HTML panel and fetches the results using WebKit message handlers.
    // It is called by sending a message to the script parser via webkit message handler, so this works asynchronously.
    if ([json isEqualToString:@"(null)"]) json = @"{}";
    
    if (self.htmlPanel.callback != nil) {
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        
        JSValue* callback = self.htmlPanel.callback;
        id arguments = @[];
        
        if (!error) {
            arguments = @[jsonData];
        } else {
            [self reportError:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
        }
        
        [self.htmlPanel closePanel:nil];
        [self runCallback:callback withArguments:arguments];
        
        self.htmlPanel.callback = nil;
    } else {
        // If there was no callback, it marks the end of the script
        [self.htmlPanel closePanel:nil];
        [self end];
    }
}


#pragma mark - WebKit controller and message listener

- (bool)promisesAvailable
{
#if !TARGET_OS_IOS
    if (@available(macOS 11.0, *)) return true;
    else return false;
#else
    return true;
#endif
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"log"]) [self log:message.body];
    
    // The following methods will require a real JS context, so if it's no longer there, do nothing.
    if (self.context == nil) return;
    
    if ([message.name isEqualToString:@"sendData"]) {
        [self receiveDataFromHTMLPanel:message.body];
    }
    else if ([message.name isEqualToString:@"call"]) {
        [self.context evaluateScript:message.body];
    }
    else if ([message.name isEqualToString:@"callAndLog"]) {
        [self.context evaluateScript:message.body];
        [self log:[NSString stringWithFormat:@"Evaluate: %@", message.body]];
    }
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler {
    if ([message.name isEqualToString:@"callAndWait"]) {
        JSValue* value = [self.context evaluateScript:message.body];
        
        id returnValue;
        if (value.isArray) returnValue = value.toArray;
        else if (value.isNumber) returnValue = value.toNumber;
        else if (value.isObject) returnValue = value.toDictionary;
        else if (value.isString) returnValue = value.toString;
        else if (value.isDate) returnValue = value.toDate;
        else returnValue = nil;

        if (returnValue) replyHandler(returnValue, nil);
        else replyHandler(nil, @"Could not convert return value to JSON.");
    }
}


#pragma mark - HTML view utils

/**
 HTML view creation accepts different types of arguments as the HTML parameter. Love you, JS.
 You can provide either a single `String`, an array `[htmlContent, headers]` or an object: `{ content: string, headers: string }`. This method converts those arguments into correct format.
 */
- (NSDictionary*)htmlObjectFromValue:(JSValue*)htmlContent
{
    NSMutableDictionary<NSString*, NSString*>* html = NSMutableDictionary.new;
    
    if (htmlContent.isString) {
        html[@"content"] = htmlContent.toString;
    } else if (htmlContent.isArray && htmlContent.toArray.count > 0) {
        NSArray* components = htmlContent.toArray;
        html[@"content"] = components[0];
        if (components.count > 1) html[@"headers"] = components[1];
    } else if (htmlContent.isObject) {
        [html setDictionary:htmlContent.toDictionary];
    }
    
    return html;
}



@end
