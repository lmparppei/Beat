//
//  PreviewViewController.m
//  fountainQuickLook
//
//  Created by Lauri-Matti Parppei on 13.1.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>

#import "PreviewViewController.h"

#import "ContinuousFountainParser.h"
#import "BeatPreview.h"

@interface PreviewViewController () <QLPreviewingController>
@property (nonatomic) IBOutlet WKWebView *webView;
@property (nonatomic) IBOutlet WebView *webView2;
@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
}

/*
 * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
 *
- (void)preparePreviewOfSearchableItemWithIdentifier:(NSString *)identifier queryString:(NSString *)queryString completionHandler:(void (^)(NSError * _Nullable))handler {
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    handler(nil);
}
*/

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {	
	// Read contents into file and then parse into FNHTMLScript
	NSError *error;
	NSString *file = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
	
	if (!error) {
		BeatPreview *preview = [[BeatPreview alloc] initWithDocument:nil];
		NSString *html = [preview createPreviewFor:file type:BeatQuickLookPreview];
		[[self.webView2 mainFrame] loadHTMLString:html baseURL:nil];
	} else {
		[[self.webView2 mainFrame] loadHTMLString:[NSString stringWithFormat:@"<html>%@</html>", error] baseURL:nil];
	}
 
	
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.
	handler(nil);
}

@end

