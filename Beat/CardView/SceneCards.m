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
#import "RegExCategories.h"
#import <WebKit/WebKit.h>

#define SNIPPET_LENGTH 190

@interface SceneCards ()
@property (nonatomic) NSArray* cards;
@end

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

	NSString* content = [NSString stringWithFormat:@"<html><head><title>Index Cards</title><style>%@</style>", css];
	content = [content stringByAppendingFormat:@"<script>%@</script>", dragula];
	content = [content stringByAppendingFormat:@"</head><body>"];
	
	// Spinner
	content = [content stringByAppendingFormat:@"<div id='wait'><div class='lds-spinner'><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div></div></div>"];
	
	content = [content stringByAppendingString:@"<div id='print' class='ui'>⎙ Print</div>"];
	
	content = [content stringByAppendingString:@"<div id='close' class='ui'>✕</div><div id='debug'></div><div id='container'>"];
	content = [content stringByAppendingFormat:@"</div><script>%@</script></body></html>", javaScript];
	
	[_cardView loadHTMLString:content baseURL:nil];
}
/*
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
*/

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

/*

 New version
 
 */

- (void)reload {
	[self reloadCardsWithVisibility:NO changed:-1];
}
- (void)reloadCardsWithVisibility:(bool)alreadyVisible changed:(NSInteger)changedIndex {
	_cards = [self getSceneCards];
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_cards options:NSJSONWritingPrettyPrinted error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	NSLog(@"json %@", json);
	
	NSString *jsCode;
	
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
	
	NSLog(@"NEW JS: %@", jsCode);
	[_cardView evaluateJavaScript:jsCode completionHandler:nil];
}

- (NSArray *) getSceneCards {
	// Returns an array of dictionaries containing the card data
	NSMutableArray *sceneCards = [NSMutableArray array];
	NSInteger index = 0;

	for (OutlineScene *scene in [self.delegate getOutlineItems]) {
		if (scene.line.type != synopse) {
			NSDictionary *sceneCard = @{
				@"sceneNumber": (scene.sceneNumber) ? scene.sceneNumber : @"",
				@"name": (scene.string) ? scene.string : @"",
				@"title": (scene.string) ? scene.string : @"", // for weird backwards compatibility stuff
				@"color": (scene.color) ? [scene.color lowercaseString] : @"",
				@"snippet": [self snippet:scene],
				@"type": [scene.line typeAsString],
				@"sceneIndex": [NSNumber numberWithInteger:index],
				@"selected": [NSNumber numberWithBool:[self isSceneSelected:scene]],
				@"position": [NSNumber numberWithInteger:scene.sceneStart],
				@"lineIndex": [NSNumber numberWithInteger:[_delegate.lines indexOfObject:scene.line]],
				@"omited": [NSNumber numberWithBool:scene.omited],
				@"depth": [NSNumber numberWithInteger:scene.sectionDepth]
			};
			
			[sceneCards addObject:sceneCard];
		}
		
		index++;
	}
	
	return sceneCards;
}
- (bool)isSceneSelected:(OutlineScene*)scene {
	NSInteger position = self.delegate.selectedRange.location;
	
	if (position >= scene.sceneStart && position < scene.sceneStart + scene.sceneLength) return YES;
	else return NO;
}

- (NSString *) snippet:(OutlineScene *)scene {
	NSUInteger index = [_delegate.lines indexOfObject:scene.line];
	
	// If we won't reach the end of file with this, let's take out a snippet from the script for the card
	NSUInteger lineIndex = index + 1;
	NSString * snippet = @"";
	
	// Get first paragraph
	// Somebody might be just using card view to craft a step outline, so we need to check that this line is not a scene heading.
	// Also, we'll use SYNOPSIS line as the snippet in case it's the first line
	while (lineIndex < _delegate.lines.count) {
			
		Line* snippetLine = [_delegate.lines objectAtIndex:lineIndex];
		if (snippetLine.type != heading && snippetLine.type != section && !(snippetLine.omited && !snippetLine.note)) {
			snippet = [[_delegate.lines objectAtIndex:lineIndex] stripFormattingCharacters];
			break;
		}
		lineIndex++;
	}
	
	// If it's longer than we want, split into sentences
	if ([snippet length] > SNIPPET_LENGTH) {
		NSMutableArray *sentences = [NSMutableArray arrayWithArray:[snippet matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
		NSString *result = @"";
		
		// If there are no real sentences in the paragraph, just cut it and add ... after the text
		if (sentences.count < 1) return [[snippet substringToIndex:SNIPPET_LENGTH - 3] stringByAppendingString:@"..."];

		// Add as many sentences as possible
		for (NSString *sentence in sentences) {
			result = [result stringByAppendingString:sentence];
			if ([result length] > SNIPPET_LENGTH || [result length] > SNIPPET_LENGTH - 15) break;
		}
		
		if ([result length]) snippet = result; else snippet = @"";
	}
	
	return snippet;
}


- (void)printCardsWithInfo:(NSPrintInfo *)printInfo {
	NSWindow *window = NSApp.mainWindow;
	if (!window) window = NSApp.windows.firstObject;
	
	NSError *error = nil;
	
	// A4 842px
			
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardPrintCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSMutableArray *htmlCards = [NSMutableArray array];
	
	_cards = [self getSceneCards];
	
	for (NSDictionary *scene in _cards) {
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
							"</div>", scene[@"sceneNumber"], scene[@"name"], scene[@"snippet"]];
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
