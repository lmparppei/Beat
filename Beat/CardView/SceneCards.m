//
//  SceneCards.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 This module prints out both the screen and print versions of the scene cards.
 Some of the stuff is still handled in Document.m, because I ran out of energy.
 Note that WebPrinter IS NOT agnostic or reusable anywhere, it's specifically
 customized for use with scene cards and has forced landscape paper orientation.

 */

#import "SceneCards.h"
#import "WebPrinter.h"
#import "OutlineScene.h"
#import <WebKit/WebKit.h>

@implementation SceneCards

- (instancetype) initWithWebView:(WKWebView *)webView {

	_cardView = webView;
	_webPrinter = [[WebPrinter alloc] init];
	// BTW, we need to retain the webPrinter in memory, because it acts as delegate and ARC seems to remove references to its properties, causing a crash. Remember to release if needed.
	
	[self screenView];
	return [super init];
}

- (void) screenView {
	NSError *error = nil;
	
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"CardView.js" ofType:@""];
	NSString *javaScript = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *dragulaPath = [[NSBundle mainBundle] pathForResource:@"dragula.js" ofType:@""];
	NSString *dragula = [NSString stringWithContentsOfFile:dragulaPath encoding:NSUTF8StringEncoding error:&error];

	NSString* content = [NSString stringWithFormat:@"<html><head><style>%@</style>", css];
	content = [content stringByAppendingFormat:@"<script>%@</script>", dragula];
	content = [content stringByAppendingFormat:@"</head><body>"];
	
	// Spinner
	content = [content stringByAppendingFormat:@"<div id='wait'><div class='lds-spinner'><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div></div></div>"];
	
	content = [content stringByAppendingString:@"<div id='print' class='ui'>⎙ Print</div>"];
	
	content = [content stringByAppendingString:@"<div id='close' class='ui'>✕</div><div id='debug'></div><div id='container'>"];
	content = [content stringByAppendingFormat:@"</div><script>%@</script></body></html>", javaScript];
	
	[_cardView loadHTMLString:content baseURL:nil];
}


- (void) showCards:(NSArray*)cards alreadyVisible:(bool)alreadyVisible changedIndex:(NSInteger)changedIndex {
		
	NSString * jsCode;
	
	// The card view will scroll to current scene by default.
	// If the cards are already visible, we'll tell it not to scroll.
	NSString *json = @"[";
	for (NSString *card in cards) {
		json = [json stringByAppendingFormat:@"{ %@ },", card];
	}
	json = [json stringByAppendingString:@"]"];
	
	if (alreadyVisible && changedIndex > -1) {
		// Already visible, changed index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true, %lu);", json, changedIndex];
	} else if (alreadyVisible && changedIndex < 0) {
		// Already visible, no index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true);", json];
	} else {
		// Fresh new view
		jsCode = [NSString stringWithFormat:@"createCards(%@);", json];
	}
	
	[_cardView evaluateJavaScript:jsCode completionHandler:nil];
}

- (void)printCards:(NSArray *)cards printInfo:(NSPrintInfo *)printInfo {
	NSWindow *window = NSApp.mainWindow;
	if (!window) window = NSApp.windows.firstObject;
	
	NSError *error = nil;
	
	// A4 842px
			
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardPrintCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSMutableArray *htmlCards = [NSMutableArray array];
	
	for (NSDictionary *scene in cards) {
		NSString * type = scene[@"type"];
		NSString *card = @"";
		if ([type isEqualToString:@"Heading"]) {
			card = [NSString stringWithFormat:
							  @"<div class='cardContainer'>"
								"<div class='card'>"
									"<div class='header'>"
										"<div class='sceneNumber'>%@</div> <h3>%@</h3>"
									"</div>"
									"<p>%@</p>"
								"</div>"
							"</div>", scene[@"sceneNumber"], scene[@"title"], scene[@"snippet"]];
			/*
			<div sceneIndex='" + card.sceneIndex + "' class='cardContainer'><div lineIndex='" +
				card.lineIndex + "' pos='" + card.position + "' " +
				"sceneIndex='" + card.sceneIndex + "' " +
				"class='card" + color + status + changed +
				"'>"+
			"<div class='header'><div class='sceneNumber'>" + card.sceneNumber	+ "</div>" +
			"<h3>" + card.name + "</h3></div>" +
			"<p>" + card.snippet + "</p></div></div>";
			 */
		} else {
			// Do something
		}
		if ([card length]) [htmlCards addObject:card];
	}
	
	if (htmlCards.count < 1) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"No Printable Cards";
        alert.informativeText = @"You have no scenes set up in the script. Scene cards don't include section headers and synopses.";
		alert.alertStyle = NSAlertStyleWarning;
        [alert beginSheetModalForWindow:window completionHandler:nil];
		return;
	}
	
	NSMutableString *html = [NSMutableString stringWithFormat:@""];
	
	//NSInteger cardsPerRow = round((printInfo.paperSize.width - 20) / 165);
	NSInteger cardsPerRow = 3;
	// Orientation is LANDSCAPE
	NSInteger maxRows = round((printInfo.paperSize.width - 20) / 165);
		
	NSInteger cardsOnRow = 0;
	NSInteger rows = 0;
	
	for (NSString *card in htmlCards) {
		[html appendString:card];
		cardsOnRow++;
		
		if (cardsOnRow >= cardsPerRow) {
			cardsOnRow = 0;
			rows++;
		}
		if (rows >= maxRows) {
			[html appendString:@"</section><div class='pageBreak'></div><section>"];
			rows = 0;
			cardsOnRow = 0;
		}
	}
	
	NSString* content = [NSString stringWithFormat:@"<html><head><style>%@</style></head><body><div id='container'><section>%@</section></div></body></html>", css, html];
		
	[_webPrinter printHtml:content printInfo:printInfo];
}

@end
