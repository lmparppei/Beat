//
//  PreviewViewController.m
//  fountainQuickLook
//
//  Created by Lauri-Matti Parppei on 13.1.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "PreviewViewController.h"
#import <Quartz/Quartz.h>
#import "FNScript.h"
#import "FNHTMLScript.h"

@interface PreviewViewController () <QLPreviewingController>
@property (nonatomic) IBOutlet WKWebView *webView;
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
		
		//NSLog(@"%@", file.className);
		FNScript *script = [[FNScript alloc] initWithString:@"\ntest\ntest 2\nINT."];
		//FNHTMLScript *htmlScript;
		/*
		htmlScript = [[FNHTMLScript alloc] initWithScript:script];
			
		[self.webView loadHTMLString:[htmlScript html] baseURL:nil];
		 */
	}
	
	
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.
    
    handler(nil);
}

@end

